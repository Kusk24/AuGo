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
        await performGoogleSignIn(hostedDomain: "au.edu")
    }
    
    private func performGoogleSignIn(hostedDomain: String? = nil) async {
        
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
            
            // Sign in to Firebase ONLY if domain validation passed
            let authResult = try await auth.signIn(with: credential)
            self.user = authResult.user
            self.isAuthenticated = true
            
            // Detect role and fetch profile
            detectRoleAndFetchProfile(uid: authResult.user.uid)
            
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
        // Try announcer first
        db.collection("announcers").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let data = snapshot?.data() {
                    // It's an announcer
                    do {
                        let announcer = try snapshot!.data(as: Announcer.self)
                        self.announcerProfile = announcer
                        self.role = .announcer
                        self.isProfileComplete = true
                        self.isCheckingAuth = false
                    } catch {
                        print("Error decoding announcer: \(error)")
                        self.isCheckingAuth = false
                    }
                } else {
                    // Not an announcer, try user
                    self.fetchUserProfile(uid: uid)
                }
            }
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
                    do {
                        let profile = try snapshot!.data(as: User.self)
                        self.userProfile = profile
                        self.role = .user
                        self.isProfileComplete = true
                        self.isCheckingAuth = false
                    } catch {
                        print("Error decoding user: \(error)")
                        self.isProfileComplete = false
                        self.role = .unknown
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
                "score": profile.score
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
