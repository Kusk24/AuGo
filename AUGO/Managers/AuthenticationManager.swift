// AuthenticationManager.swift
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit
import FirebaseCore
import FirebaseStorage

enum AccountRole {
    case user
    case announcer
    case unknown
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var userProfile: User?
    @Published var announcerProfile: Announcer?
    @Published var role: AccountRole = .unknown
    @Published var isAuthenticated = false
    @Published var isProfileComplete = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isCheckingAuth = true
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let notificationManager = NotificationManager.shared
    private var userProfileListener: ListenerRegistration?
    private var pendingOAuthCredential: AuthCredential?
    private var pendingOAuthEmail: String?

    var postingRestrictionMessage: String? {
        guard let status = userProfile?.status else { return nil }
        switch status {
        case .active:
            return nil
        case .suspended:
            return "Your account is suspended. Posting is temporarily disabled."
        case .banned:
            return "Your account is banned. You cannot create new posts."
        }
    }
    
    init() {
        // Check if user is already signed in
        checkAuthenticationState()
    }

    deinit {
        userProfileListener?.remove()
    }
    
    func checkAuthenticationState() {
        if let currentUser = auth.currentUser {
            self.user = currentUser
            self.isAuthenticated = true
            notificationManager.startListeningForUserNotifications(userId: currentUser.uid)
            // Determine role and fetch profile
            detectRoleAndFetchProfile(uid: currentUser.uid)
        } else {
            self.isAuthenticated = false
            self.isProfileComplete = false
            self.role = .unknown
            self.isCheckingAuth = false
            notificationManager.stopListeningForUserNotifications()
        }
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle() async {
        await signInWithGoogle(requiredRole: nil)
    }

    func signInWithMicrosoft() async {
        await signInWithMicrosoft(requiredRole: nil)
    }
    
    func signInAnnouncerWithEmailPassword(email: String, password: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Please enter announcer email and password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let authResult = try await auth.signIn(withEmail: normalizedEmail, password: trimmedPassword)
            let announcerProfile = try await fetchAnnouncerProfile(
                uid: authResult.user.uid,
                email: normalizedEmail
            )
            
            guard let announcerProfile else {
                do {
                    try auth.signOut()
                } catch {
                    print("Sign out failed after announcer email/password check: \(error)")
                }
                self.user = nil
                self.isAuthenticated = false
                self.role = .unknown
                self.isProfileComplete = false
                self.errorMessage = "This account is not registered as an announcer."
                isLoading = false
                return
            }
            
            self.user = authResult.user
            self.announcerProfile = announcerProfile
            self.role = .announcer
            self.isAuthenticated = true
            self.isProfileComplete = true
            self.isCheckingAuth = false
            notificationManager.startListeningForUserNotifications(userId: authResult.user.uid)
            
            await notificationManager.registerDeviceForNotifications(userId: authResult.user.uid)
        } catch {
            if let firestoreErrorCode = FirestoreErrorCode.Code(rawValue: (error as NSError).code),
               firestoreErrorCode == .permissionDenied {
                errorMessage = "Login succeeded, but Firestore rules blocked announcer profile access."
                print("Announcer profile access blocked by Firestore rules: \(error)")
                isLoading = false
                return
            }
            
            if let errorCode = AuthErrorCode(rawValue: (error as NSError).code) {
                switch errorCode {
                case .wrongPassword, .invalidCredential, .userNotFound:
                    errorMessage = "Invalid announcer email or password."
                default:
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
            print("Announcer email/password sign-in error: \(error)")
        }
        
        isLoading = false
    }
    
    func sendAnnouncerPasswordReset(email: String) async -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !normalizedEmail.isEmpty else {
            errorMessage = "Please enter announcer email."
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let isAnnouncer = try await db.collection("announcers")
                .whereField("email", isEqualTo: normalizedEmail)
                .limit(to: 1)
                .getDocuments()
                .documents
                .isEmpty == false
            
            guard isAnnouncer else {
                errorMessage = "No announcer account found for this email."
                isLoading = false
                return false
            }
            
            try await auth.sendPasswordReset(withEmail: normalizedEmail)
            isLoading = false
            return true
        } catch {
            errorMessage = "Password reset failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    private func signInWithGoogle(requiredRole: AccountRole?) async {
        isLoading = true
        errorMessage = nil
        
        // Read iOS client ID from active Firebase config instead of hardcoding.
        let clientID = FirebaseApp.app()?.options.clientID ?? ""
        guard !clientID.isEmpty else {
            errorMessage = "Missing Google client ID in Firebase configuration."
            isLoading = false
            return
        }
        
        // Configure Google Sign-In with domain restriction
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Add hosted domain restriction (only allow @au.edu emails)
        // Note: This shows a hint to users but doesn't enforce on client side
        // You MUST also validate on the server/Firebase side
        await performGoogleSignIn(
            hostedDomain: "au.edu",
            requiredRole: requiredRole
        )
    }

    private func signInWithMicrosoft(requiredRole: AccountRole?) async {
        isLoading = true
        errorMessage = nil
        var attemptedCredential: AuthCredential?

        do {
            let provider = OAuthProvider(providerID: "microsoft.com")
            if let tenantID = microsoftTenantID {
                provider.customParameters = ["tenant": tenantID]
            }

            let credential = try await oauthCredential(from: provider)
            attemptedCredential = credential
            let authResult = try await auth.signIn(with: credential)

            guard let email = authResult.user.email?.lowercased(),
                  email.hasSuffix("@au.edu") else {
                try? auth.signOut()
                self.user = nil
                self.isAuthenticated = false
                self.role = .unknown
                self.isProfileComplete = false
                self.errorMessage = "Access denied. Please sign in with your @au.edu email address."
                isLoading = false
                return
            }

            try await linkPendingCredentialIfNeeded(signedInUser: authResult.user)
            await handleAuthResult(authResult, requiredRole: requiredRole, providerID: "microsoft.com")
        } catch {
            if await handleAccountExistsWithDifferentCredential(
                error,
                attemptedProviderID: "microsoft.com",
                fallbackCredential: attemptedCredential
            ) {
                isLoading = false
                return
            }
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            print("Microsoft Sign-In Error: \(error)")
        }

        isLoading = false
    }
    
    private func performGoogleSignIn(
        hostedDomain: String? = nil,
        requiredRole: AccountRole? = nil
    ) async {
        
        // Get root view controller (compatible with multi-scene apps)
        let presentingViewController: UIViewController? = {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.keyWindow?.rootViewController {
                return root
            }
            return nil
        }()
        
        guard let presentingViewController = presentingViewController else {
            errorMessage = "No root view controller found"
            isLoading = false
            return
        }
        
        var attemptedCredential: AuthCredential?
        do {
            // Present Google Sign-In with optional domain hint
            let result: GIDSignInResult
            
            if let domain = hostedDomain {
                // Sign in with domain hint (shows only emails from this domain)
                result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presentingViewController,
                    hint: nil,
                    additionalScopes: nil
                )
                
                // IMPORTANT: Validate the email domain BEFORE Firebase authentication
                guard let email = result.user.profile?.email,
                      email.lowercased().hasSuffix("@\(domain.lowercased())") else {
                    // Sign out immediately if domain doesn't match
                    GIDSignIn.sharedInstance.signOut()
                    errorMessage = "Access denied. Please sign in with your @\(domain) email address."
                    isLoading = false
                    return
                }
            } else {
                result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            }
            
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token"
                isLoading = false
                return
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            attemptedCredential = credential
            
            let authResult = try await auth.signIn(with: credential)
            try await linkPendingCredentialIfNeeded(signedInUser: authResult.user)
            await handleAuthResult(authResult, requiredRole: requiredRole, providerID: "google.com")
            
        } catch {
            if await handleAccountExistsWithDifferentCredential(
                error,
                attemptedProviderID: "google.com",
                fallbackCredential: attemptedCredential
            ) {
                isLoading = false
                return
            }
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            print("Google Sign-In Error: \(error)")
        }
        
        isLoading = false
    }

    private var microsoftTenantID: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "MICROSOFT_TENANT_ID") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func oauthCredential(from provider: OAuthProvider) async throws -> AuthCredential {
        try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialWith(nil) { credential, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let credential else {
                    continuation.resume(throwing: NSError(
                        domain: "AuthenticationManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to obtain OAuth credential."]
                    ))
                    return
                }
                continuation.resume(returning: credential)
            }
        }
    }

    private func handleAuthResult(
        _ authResult: AuthDataResult,
        requiredRole: AccountRole?,
        providerID: String
    ) async {
        if requiredRole == .announcer {
            do {
                let announcerProfile = try await fetchAnnouncerProfile(
                    uid: authResult.user.uid,
                    email: authResult.user.email?.lowercased()
                )
                if announcerProfile == nil {
                    try? auth.signOut()
                    if providerID == "google.com" {
                        GIDSignIn.sharedInstance.signOut()
                    }
                    self.user = nil
                    self.isAuthenticated = false
                    self.role = .unknown
                    self.isProfileComplete = false
                    self.errorMessage = "This account is not registered as an announcer."
                    return
                }
            } catch {
                self.errorMessage = "Failed to verify announcer profile: \(error.localizedDescription)"
                return
            }
        }

        self.user = authResult.user
        self.isAuthenticated = true
        notificationManager.startListeningForUserNotifications(userId: authResult.user.uid)

        if requiredRole == .announcer {
            detectRoleAndFetchProfile(uid: authResult.user.uid)
        } else {
            fetchUserProfile(uid: authResult.user.uid)
        }

        await notificationManager.registerDeviceForNotifications(userId: authResult.user.uid)
    }

    private func handleAccountExistsWithDifferentCredential(
        _ error: Error,
        attemptedProviderID: String,
        fallbackCredential: AuthCredential? = nil
    ) async -> Bool {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code),
              code == .accountExistsWithDifferentCredential else {
            return false
        }

        let nsError = error as NSError
        let email = (nsError.userInfo[AuthErrorUserInfoEmailKey] as? String)?.lowercased()
        let pendingCredential =
            (nsError.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential) ??
            (nsError.userInfo["FIRAuthErrorUserInfoPendingCredentialKey"] as? AuthCredential) ??
            fallbackCredential

        pendingOAuthCredential = pendingCredential
        pendingOAuthEmail = email

        guard let email else {
            errorMessage = "Account already exists with another sign-in method. Sign in with your existing provider first."
            return true
        }

        errorMessage = "This email (\(email)) already exists. Use your existing sign-in method once and AUGO will link providers automatically."

        return true
    }

    private func linkPendingCredentialIfNeeded(signedInUser: FirebaseAuth.User) async throws {
        guard let pending = pendingOAuthCredential,
              let pendingEmail = pendingOAuthEmail?.lowercased(),
              let currentEmail = signedInUser.email?.lowercased(),
              pendingEmail == currentEmail else {
            return
        }

        do {
            _ = try await signedInUser.link(with: pending)
        } catch {
            if let code = AuthErrorCode(rawValue: (error as NSError).code),
               code == .credentialAlreadyInUse || code == .providerAlreadyLinked {
                // Ignore; account is effectively linked or already bound elsewhere.
            } else {
                throw error
            }
        }

        pendingOAuthCredential = nil
        pendingOAuthEmail = nil
    }
    
    // MARK: - Detect Role and Fetch Profile
    func detectRoleAndFetchProfile(uid: String) {
        let providerIDs = auth.currentUser?.providerData.map(\.providerID) ?? []
        if providerIDs.contains("google.com") || providerIDs.contains("microsoft.com") {
            // Keep student Google users out of announcer-only reads
            fetchUserProfile(uid: uid)
            return
        }
        
        Task {
            do {
                let announcerProfile = try await fetchAnnouncerProfile(
                    uid: uid,
                    email: auth.currentUser?.email?.lowercased()
                )
                
                if let announcerProfile {
                    self.announcerProfile = announcerProfile
                    self.role = .announcer
                    self.isProfileComplete = true
                    self.isCheckingAuth = false
                } else {
                    // Not an announcer, try user
                    self.fetchUserProfile(uid: uid)
                }
            } catch {
                print("Error fetching announcer profile: \(error)")
                self.fetchUserProfile(uid: uid)
            }
        }
    }
    
    private func fetchAnnouncerProfile(uid: String, email: String?) async throws -> Announcer? {
        var lastError: Error?
        
        do {
            let announcerByUID = try await db.collection("announcers").document(uid).getDocument()
            if announcerByUID.exists {
                return try announcerByUID.data(as: Announcer.self)
            }
        } catch {
            lastError = error
        }
        
        guard let email, !email.isEmpty else {
            if let lastError { throw lastError }
            return nil
        }
        
        do {
            let querySnapshot = try await db.collection("announcers")
                .whereField("email", isEqualTo: email)
                .limit(to: 1)
                .getDocuments()
            
            guard let firstDoc = querySnapshot.documents.first else { return nil }
            return try firstDoc.data(as: Announcer.self)
        } catch {
            if let lastError { throw lastError }
            throw error
        }
    }
    
    // MARK: - Fetch User Profile
    func fetchUserProfile(uid: String) {
        userProfileListener?.remove()
        userProfileListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    print("Error fetching profile: \(error)")
                    self.isProfileComplete = false
                    self.role = .unknown
                    self.isCheckingAuth = false
                    return
                }
                
                if let _ = snapshot?.data() {
                    if let profile = self.mapUserProfile(snapshot: snapshot!) {
                        let previousProfile = self.userProfile
                        self.userProfile = profile
                        self.role = .user
                        self.isProfileComplete = true
                        self.isCheckingAuth = false
                        self.emitModerationNotificationsIfNeeded(
                            oldProfile: previousProfile,
                            newProfile: profile
                        )
                    } else {
                        print("Error decoding user profile. Falling back to incomplete profile flow.")
                        self.isProfileComplete = false
                        self.role = .user
                        self.isCheckingAuth = false
                    }
                } else {
                    self.isProfileComplete = false
                    self.role = .user  // Default to user for profile creation
                    self.isCheckingAuth = false
                }
            }
        }
    }

    private func emitModerationNotificationsIfNeeded(oldProfile: User?, newProfile: User) {
        guard let oldProfile else { return }

        if newProfile.warningCount > oldProfile.warningCount {
            let delta = newProfile.warningCount - oldProfile.warningCount
            notificationManager.addInAppNotification(
                id: "warn_\(newProfile.id ?? "user")_\(newProfile.warningCount)",
                title: "Warning Received",
                body: delta == 1
                    ? "Your account received a warning."
                    : "Your account received \(delta) new warnings."
            )
        }

        if newProfile.status != oldProfile.status {
            switch newProfile.status {
            case .suspended:
                notificationManager.addInAppNotification(
                    id: "status_\(newProfile.id ?? "user")_suspended",
                    title: "Account Suspended",
                    body: "Your account has been suspended by admin."
                )
            case .banned:
                notificationManager.addInAppNotification(
                    id: "status_\(newProfile.id ?? "user")_banned",
                    title: "Account Banned",
                    body: "Your account has been banned by admin."
                )
            case .active:
                break
            }
        }
    }
    
    private func mapUserProfile(snapshot: DocumentSnapshot) -> User? {
        guard let data = snapshot.data() else { return nil }
        
        let birthDate = parseFirestoreDate(data["birthDate"]) ?? Date()
        let joinedDate = parseFirestoreDate(data["joinedDate"]) ?? Date()
        let lastWarningDate = parseFirestoreDate(data["lastWarningDate"])
        
        let statusRaw = (data["status"] as? String) ?? "active"
        let status = User.UserStatus(rawValue: statusRaw) ?? .active
        
        let arCapturedCharacters: [ARCapturedCharacter] = (data["arCapturedCharacters"] as? [[String: Any]] ?? [])
            .compactMap { entry in
                guard
                    let spawnId = entry["spawnId"] as? String,
                    let title = entry["title"] as? String,
                    let assetPath = entry["assetPath"] as? String
                else { return nil }

                return ARCapturedCharacter(
                    spawnId: spawnId,
                    sourceSpawnId: entry["sourceSpawnId"] as? String,
                    title: title,
                    assetPath: assetPath,
                    preview: (entry["preview"] as? String) ?? (entry["previewPath"] as? String),
                    rarity: entry["rarity"] as? String,
                    characterDescription: entry["description"] as? String,
                    coinValue: parseDouble(entry["coinValue"]),
                    pointValue: parseInt(entry["pointValue"]),
                    catchCount: entry["catchCount"] as? Int ?? 0,
                    catchableTime: entry["catchableTime"] as? Int ?? 1,
                    lastCapturedAt: parseFirestoreDate(entry["lastCapturedAt"]),
                    nextCatchAt: parseFirestoreDate(entry["nextCatchAt"])
                )
            }

        return User(
            id: snapshot.documentID,
            studentID: (data["studentID"] as? String) ?? "",
            name: (data["name"] as? String) ?? "",
            nickname: (data["nickname"] as? String) ?? "",
            email: (data["email"] as? String) ?? "",
            faculty: (data["faculty"] as? String) ?? "",
            birthDate: birthDate,
            joinedDate: joinedDate,
            lastWarningDate: lastWarningDate,
            warningCount: (data["warningCount"] as? Int) ?? 0,
            status: status,
            score: parseInt(data["score"]),
            coinBalance: parseDouble(data["coinBalance"]),
            dailyPostCount: (data["dailyPostCount"] as? Int) ?? 0,
            dailyPostCountDate: parseFirestoreDate(data["dailyPostCountDate"]),
            lastCoinGrantDate: parseFirestoreDate(data["lastCoinGrantDate"]),
            arCapturedCharacters: arCapturedCharacters,
            profileImageURL: data["profileImageURL"] as? String,
            profileImagePath: data["profileImagePath"] as? String
        )
    }
    
    private func parseFirestoreDate(_ value: Any?) -> Date? {
        switch value {
        case let timestamp as Timestamp:
            return timestamp.dateValue()
        case let date as Date:
            return date
        case let seconds as TimeInterval:
            return Date(timeIntervalSince1970: seconds)
        case let seconds as Int:
            return Date(timeIntervalSince1970: TimeInterval(seconds))
        case let dateString as String:
            let isoWithFraction = ISO8601DateFormatter()
            isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoWithFraction.date(from: dateString) { return date }
            
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: dateString) { return date }
            return nil
        default:
            return nil
        }
    }

    private func parseDouble(_ value: Any?) -> Double {
        switch value {
        case let doubleValue as Double:
            return doubleValue
        case let intValue as Int:
            return Double(intValue)
        case let number as NSNumber:
            return number.doubleValue
        case let stringValue as String:
            return Double(stringValue) ?? 0
        default:
            return 0
        }
    }

    private func parseInt(_ value: Any?) -> Int {
        switch value {
        case let intValue as Int:
            return intValue
        case let doubleValue as Double:
            return Int(doubleValue)
        case let number as NSNumber:
            return number.intValue
        case let stringValue as String:
            return Int(stringValue) ?? 0
        default:
            return 0
        }
    }
    
    // MARK: - Create or Update User Profile
    func createOrUpdateUserProfile(uid: String, profile: User) async throws {
        isLoading = true
        errorMessage = nil
        do {
            var data: [String: Any] = [
                "studentID": profile.studentID,
                "name": profile.name,
                "nickname": profile.nickname,
                "email": profile.email,
                "faculty": profile.faculty,
                "birthDate": profile.birthDate,
                "warningCount": profile.warningCount,
                "status": profile.status.rawValue,
                "joinedDate": profile.joinedDate,
                "score": profile.score,
                "coinBalance": profile.coinBalance,
                "dailyPostCount": profile.dailyPostCount,
                "arCapturedCharacters": profile.arCapturedCharacters.map {
                    var payload: [String: Any] = [
                        "spawnId": $0.spawnId,
                        "title": $0.title,
                        "assetPath": $0.assetPath,
                        "coinValue": $0.coinValue,
                        "pointValue": $0.pointValue,
                        "catchCount": $0.catchCount,
                        "catchableTime": $0.catchableTime
                    ]
                    if let preview = $0.preview {
                        payload["preview"] = preview
                        payload["previewPath"] = preview
                    }
                    if let sourceSpawnId = $0.sourceSpawnId, !sourceSpawnId.isEmpty {
                        payload["sourceSpawnId"] = sourceSpawnId
                    }
                    if let rarity = $0.rarity, !rarity.isEmpty {
                        payload["rarity"] = rarity
                    }
                    if let description = $0.characterDescription, !description.isEmpty {
                        payload["description"] = description
                    }
                    if let lastCapturedAt = $0.lastCapturedAt {
                        payload["lastCapturedAt"] = Timestamp(date: lastCapturedAt)
                    }
                    if let nextCatchAt = $0.nextCatchAt {
                        payload["nextCatchAt"] = Timestamp(date: nextCatchAt)
                    }
                    return payload
                }
            ]

            if let profileImageURL = profile.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !profileImageURL.isEmpty {
                data["profileImageURL"] = profileImageURL
            }
            if let profileImagePath = profile.profileImagePath?.trimmingCharacters(in: .whitespacesAndNewlines),
               !profileImagePath.isEmpty {
                data["profileImagePath"] = profileImagePath
            }
            try await db.collection("users").document(uid).setData(data, merge: true)
            var profileWithId = profile
            profileWithId.id = uid
            self.userProfile = profileWithId
            self.role = .user
            self.isProfileComplete = true
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
        isLoading = false
    }

    func uploadProfileImage(uid: String, imageData: Data) async throws -> String {
        guard !uid.isEmpty else { throw NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing user ID"]) }
        guard !imageData.isEmpty else { throw NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"]) }

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let imagePath = "profile_pictures/\(uid)/\(timestamp).jpg"
        let imageRef = Storage.storage().reference(withPath: imagePath)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await imageRef.downloadURL()

        let oldPath = userProfile?.profileImagePath?.trimmingCharacters(in: .whitespacesAndNewlines)

        try await db.collection("users").document(uid).setData([
            "profileImageURL": downloadURL.absoluteString,
            "profileImagePath": imagePath,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)

        if let oldPath, !oldPath.isEmpty, oldPath != imagePath {
            do {
                try await Storage.storage().reference(withPath: oldPath).delete()
            } catch {
                // Ignore cleanup failure to avoid breaking user flow.
                print("⚠️ Failed to delete old profile image: \(error.localizedDescription)")
            }
        }

        if var profile = userProfile {
            profile.profileImageURL = downloadURL.absoluteString
            profile.profileImagePath = imagePath
            userProfile = profile
        }

        return downloadURL.absoluteString
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()
            userProfileListener?.remove()
            userProfileListener = nil
            pendingOAuthCredential = nil
            pendingOAuthEmail = nil
            notificationManager.stopListeningForUserNotifications()
            self.user = nil
            self.userProfile = nil
            self.isAuthenticated = false
            self.isProfileComplete = false
            self.isCheckingAuth = false
        } catch {
            errorMessage = error.localizedDescription
            print("Error signing out: \(error)")
        }
    }
    
    // MARK: - Fetch User Rank
    func fetchUserRank(completion: @escaping (Int) -> Void) {
        guard let currentUserID = user?.uid else {
            completion(0)
            return
        }

        // Match leaderboard ranking: ordered list by score descending, contiguous rank by position.
        db.collection("users")
            .order(by: "score", descending: true)
            .limit(to: 500)
            .getDocuments { snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("Error fetching rank: \(error)")
                        completion(0)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        completion(0)
                        return
                    }

                    let sortedDocuments = documents.sorted { lhs, rhs in
                        let leftScore = self.parseInt(lhs.data()["score"])
                        let rightScore = self.parseInt(rhs.data()["score"])
                        if leftScore == rightScore {
                            return lhs.documentID < rhs.documentID
                        }
                        return leftScore > rightScore
                    }

                    if let index = sortedDocuments.firstIndex(where: { $0.documentID == currentUserID }) {
                        completion(index + 1)
                    } else {
                        completion(0)
                    }
                }
            }
    }
}
