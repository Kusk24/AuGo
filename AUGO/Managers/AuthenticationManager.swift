// AuthenticationManager.swift
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit
import FirebaseCore

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var userProfile: User?
    @Published var isAuthenticated = false
    @Published var isProfileComplete = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isCheckingAuth = true // NEW: for initial auth check
    
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
            // Check if profile is complete
            fetchUserProfile(uid: currentUser.uid)
        } else {
            self.isAuthenticated = false
            self.isProfileComplete = false
            self.isCheckingAuth = false // Done checking, no user
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
            
            // Check if profile exists
            fetchUserProfile(uid: authResult.user.uid)
            
            // Register device for push notifications
            await notificationManager.registerDeviceForNotifications(userId: authResult.user.uid)
            
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            print("Google Sign-In Error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Fetch User Profile
    func fetchUserProfile(uid: String) {
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    print("Error fetching profile: \(error)")
                    self.isProfileComplete = false
                    self.isCheckingAuth = false
                    return
                }
                
                if let data = snapshot?.data() {
                    // Manually decode to handle @DocumentID
                    let profile = User(
                        id: uid,
                        studentID: data["studentID"] as? String ?? "",
                        name: data["name"] as? String ?? "",
                        nickname: data["nickname"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        faculty: data["faculty"] as? String ?? "",
                        birthDate: (data["birthDate"] as? Timestamp)?.dateValue() ?? Date(),
                        warningCount: data["warningCount"] as? Int ?? 0,
                        status: User.UserStatus(rawValue: data["status"] as? String ?? "active") ?? .active,
                        joinedDate: (data["joinedDate"] as? Timestamp)?.dateValue() ?? Date(),
                        score: data["score"] as? Int ?? 0,
                        fcmToken: data["fcmToken"] as? String
                    )
                    self.userProfile = profile
                    self.isProfileComplete = true
                    self.isCheckingAuth = false
                } else {
                    self.isProfileComplete = false
                    self.isCheckingAuth = false
                }
            }
        }
    }
    
    // MARK: - Save User Profile
    func saveUserProfile(_ profile: User) async throws {
        guard let uid = user?.uid else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        isLoading = true
        
        do {
            // Create dictionary manually to avoid @DocumentID encoding issues
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
            
            try await db.collection("users").document(uid).setData(data)
            
            var profileWithId = profile
            profileWithId.id = uid
            self.userProfile = profileWithId
            self.isProfileComplete = true
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            // Delete FCM token before signing out
            if let userId = user?.uid {
                Task {
                    await notificationManager.deleteToken(userId: userId)
                }
            }
            
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
