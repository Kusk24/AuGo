// AuthenticationManager.swift
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit
import FirebaseCore

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
    
    init() {
        // Check if user is already signed in
        checkAuthenticationState()
    }
    
    func checkAuthenticationState() {
        if let currentUser = auth.currentUser {
            self.user = currentUser
            self.isAuthenticated = true
            // Determine role and fetch profile
            detectRoleAndFetchProfile(uid: currentUser.uid)
        } else {
            self.isAuthenticated = false
            self.isProfileComplete = false
            self.role = .unknown
            self.isCheckingAuth = false
        }
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle() async {
        await signInWithGoogle(requiredRole: nil)
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
        
        // Use the iOS client ID from Firebase Console
        let clientID = "725089765922-4avllhgdh56mkfqfiq8gdag958agi2h5.apps.googleusercontent.com"
        
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
            
            let authResult = try await auth.signIn(with: credential)
            
            if requiredRole == .announcer {
                let announcerProfile = try await fetchAnnouncerProfile(
                    uid: authResult.user.uid,
                    email: authResult.user.email?.lowercased()
                )
                
                if announcerProfile == nil {
                    do {
                        try auth.signOut()
                    } catch {
                        print("Sign out failed after announcer check: \(error)")
                    }
                    GIDSignIn.sharedInstance.signOut()
                    self.user = nil
                    self.isAuthenticated = false
                    self.role = .unknown
                    self.isProfileComplete = false
                    self.errorMessage = "This Google account is not registered as an announcer."
                    isLoading = false
                    return
                }
            }
            
            self.user = authResult.user
            self.isAuthenticated = true
            
            if requiredRole == .announcer {
                // Explicit announcer sign-in path
                detectRoleAndFetchProfile(uid: authResult.user.uid)
            } else {
                // Student Google SSO should always route through the user flow
                fetchUserProfile(uid: authResult.user.uid)
            }
            
            // Register device for push notifications
            await notificationManager.registerDeviceForNotifications(userId: authResult.user.uid)
            
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            print("Google Sign-In Error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Detect Role and Fetch Profile
    func detectRoleAndFetchProfile(uid: String) {
        let providerIDs = auth.currentUser?.providerData.map(\.providerID) ?? []
        if providerIDs.contains("google.com") {
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
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
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
                        self.userProfile = profile
                        self.role = .user
                        self.isProfileComplete = true
                        self.isCheckingAuth = false
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
    
    private func mapUserProfile(snapshot: DocumentSnapshot) -> User? {
        guard let data = snapshot.data() else { return nil }
        
        let birthDate = parseFirestoreDate(data["birthDate"]) ?? Date()
        let joinedDate = parseFirestoreDate(data["joinedDate"]) ?? Date()
        let lastWarningDate = parseFirestoreDate(data["lastWarningDate"])
        
        let statusRaw = (data["status"] as? String) ?? "active"
        let status = User.UserStatus(rawValue: statusRaw) ?? .active
        
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
            score: (data["score"] as? Int) ?? 0,
            coinBalance: (data["coinBalance"] as? Int) ?? 0,
            dailyPostCount: (data["dailyPostCount"] as? Int) ?? 0,
            dailyPostCountDate: parseFirestoreDate(data["dailyPostCountDate"]),
            lastCoinGrantDate: parseFirestoreDate(data["lastCoinGrantDate"])
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
    
    // MARK: - Create or Update User Profile
    func createOrUpdateUserProfile(uid: String, profile: User) async throws {
        isLoading = true
        errorMessage = nil
        do {
            let data: [String: Any] = [
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
                "dailyPostCount": profile.dailyPostCount
            ]
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
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()
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
        guard let currentScore = userProfile?.score else {
            completion(0)
            return
        }
        
        // Query all users with score higher than current user
        db.collection("users")
            .whereField("score", isGreaterThan: currentScore)
            .getDocuments { snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("Error fetching rank: \(error)")
                        completion(0)
                        return
                    }
                    
                    // Rank is number of users with higher score + 1
                    let rank = (snapshot?.documents.count ?? 0) + 1
                    completion(rank)
                }
            }
    }
}
