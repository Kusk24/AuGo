import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

enum AccountRole {
    case unknown
    case user
    case announcer
}

@MainActor
final class AuthenticationManager: ObservableObject {

    // MARK: - Auth State
    @Published var user: FirebaseAuth.User?
    @Published var role: AccountRole = .unknown

    // Profiles
    @Published var userProfile: User?
    @Published var announcerProfile: Announcer?

    // UI State
    @Published var isAuthenticated = false
    @Published var isProfileComplete = false
    @Published var isLoading = false
    @Published var isCheckingAuth = true
    @Published var errorMessage: String?

    // Firebase
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    // MARK: - Init
    init() {
        checkAuthenticationState()
    }

    // MARK: - Initial Auth Check
    func checkAuthenticationState() {
        guard let currentUser = auth.currentUser else {
            resetState()
            return
        }

        user = currentUser
        isAuthenticated = true
        isCheckingAuth = true

        Task {
            await resolveRole(uid: currentUser.uid)
        }
    }

    // MARK: - Google Sign In
    func signInWithGoogle() async {
        isLoading = true
        isCheckingAuth = true
        errorMessage = nil

        let clientID = "725089765922-4avllhgdh56mkfqfiq8gdag958agi2h5.apps.googleusercontent.com"
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        defer { isLoading = false }

        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let presentingVC = scene.windows.first?.rootViewController
        else {
            failAuth("No root view controller")
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)

            guard
                let email = result.user.profile?.email.lowercased(),
                email.hasSuffix("@au.edu")
            else {
                GIDSignIn.sharedInstance.signOut()
                failAuth("School email required")
                return
            }

            guard let idToken = result.user.idToken?.tokenString else {
                failAuth("Missing ID token")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await auth.signIn(with: credential)

            user = authResult.user
            isAuthenticated = true

            await resolveRole(uid: authResult.user.uid)

        } catch {
            failAuth(error.localizedDescription)
        }
    }

    // MARK: - ROLE RESOLUTION
    private func resolveRole(uid: String) async {

        do {
            let email = auth.currentUser?.email?.lowercased() ?? ""

            // 1️⃣ CHECK ANNOUNCER (BY EMAIL)
            if !email.isEmpty {
                let snap = try await db
                    .collection("announcers")
                    .whereField("email", isEqualTo: email)
                    .limit(to: 1)
                    .getDocuments()

                if let doc = snap.documents.first {
                    let data = doc.data()

                    let announcer = Announcer(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        phone: data["phone"] as? String ?? "",
                        affiliationName: data["affiliation_name"] as? String ?? "",
                        affiliationType: .other,
                        role: data["role"] as? String ?? "",
                        status: .active,
                        totalAnnouncements: data["total_announcements"] as? Int ?? 0,
                        joinedDate: (data["joined_date"] as? Timestamp)?.dateValue() ?? Date()
                    )

                    self.announcerProfile = announcer
                    self.role = .announcer
                    self.isProfileComplete = true
                    self.isCheckingAuth = false
                    return
                }
            }

            // 2️⃣ CHECK USER (BY UID)
            let userSnap = try await db.collection("users").document(uid).getDocument()

            if let data = userSnap.data() {
                let profile = try Firestore.Decoder().decode(User.self, from: data)
                self.userProfile = profile
                self.role = .user
                self.isProfileComplete = true
                self.isCheckingAuth = false
                return
            }

            // 3️⃣ NEW USER
            self.role = .user
            self.isProfileComplete = false
            self.isCheckingAuth = false

        } catch {
            failAuth("Account configuration error")
        }
    }

    // MARK: - Save User Profile
    func saveUserProfile(_ profile: User) async throws {
        guard let uid = user?.uid else { return }

        isLoading = true
        defer { isLoading = false }

        let data: [String: Any] = [
            "studentID": profile.studentID,
            "name": profile.name,
            "nickname": profile.nickname,
            "email": profile.email,
            "faculty": profile.faculty,
            "birthDate": profile.birthDate,
            "joinedDate": profile.joinedDate,
            "lastWarningDate": profile.lastWarningDate as Any,
            "warningCount": profile.warningCount,
            "status": profile.status.rawValue,
            "score": profile.score
        ]

        try await db.collection("users").document(uid).setData(data)

        var updated = profile
        updated.id = uid
        userProfile = updated
        isProfileComplete = true
    }

    // MARK: - User Rank (UNCHANGED)
    func fetchUserRank(completion: @escaping (Int) -> Void) {
        guard let uid = user?.uid else {
            completion(0)
            return
        }

        db.collection("users")
            .order(by: "score", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch rank: \(error)")
                    completion(0)
                    return
                }

                guard let docs = snapshot?.documents else {
                    completion(0)
                    return
                }

                for (index, doc) in docs.enumerated() {
                    if doc.documentID == uid {
                        completion(index + 1)
                        return
                    }
                }

                completion(0)
            }
    }

    // MARK: - Sign Out
    func signOut() {
        try? auth.signOut()
        GIDSignIn.sharedInstance.signOut()
        resetState()
    }

    // MARK: - Failure / Reset
    private func failAuth(_ message: String) {
        resetState()
        errorMessage = message
    }

    private func resetState() {
        user = nil
        userProfile = nil
        announcerProfile = nil
        role = .unknown
        isAuthenticated = false
        isProfileComplete = false
        isCheckingAuth = false
    }
}
