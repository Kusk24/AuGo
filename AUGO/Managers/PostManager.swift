import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

@MainActor
class PostManager: ObservableObject {
    @Published var userPosts: [Post] = []
    @Published var allPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var userPostsListener: ListenerRegistration?
    private var allPostsListener: ListenerRegistration?
    
    // FIX: deinit cannot call MainActor methods directly.
    deinit {
        let uListener = userPostsListener
        let aListener = allPostsListener
        // We remove them on whatever thread deinit is running on
        uListener?.remove()
        aListener?.remove()
    }
    
    // MARK: - Create Post
    func createPost(content: String, category: Post.Category, userId: String, coordinate: CLLocationCoordinate2D) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        let data: [String: Any] = [
            "userId": userId,
            "content": content,
            "category": category.rawValue,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "date": Timestamp(date: Date()),
            "likeCount": 0,
            "dislikeCount": 0,
            "reportCount": 0,
            "status": Post.Status.active.rawValue
        ]
        
        do {
            let docRef = try await db.collection("posts").addDocument(data: data)
            isLoading = false
            return docRef.documentID
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Fetch User Posts (Real-time)
    func fetchUserPosts(userId: String) {
        userPostsListener?.remove()
        
        userPostsListener = db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                // Ensure UI updates happen on the Main Actor
                Task { @MainActor in
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.userPosts = snapshot?.documents.compactMap { self.parsePost(from: $0) } ?? []
                }
            }
    }
    
    // MARK: - Fetch All Posts (Real-time)
    func fetchAllPosts() {
        allPostsListener?.remove()
        
        allPostsListener = db.collection("posts")
            .whereField("status", isEqualTo: Post.Status.active.rawValue)
            .order(by: "date", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.allPosts = snapshot?.documents.compactMap { self.parsePost(from: $0) } ?? []
                }
            }
    }
    
    // MARK: - Delete Post
    func deletePost(_ postId: String) async throws {
        isLoading = true
        do {
            try await db.collection("posts").document(postId).delete()
            isLoading = false
        } catch {
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Like/Dislike/Report
    func likePost(_ postId: String) async throws {
        try await db.collection("posts").document(postId).updateData([
            "likeCount": FieldValue.increment(Int64(1))
        ])
    }
    
    func dislikePost(_ postId: String) async throws {
        try await db.collection("posts").document(postId).updateData([
            "dislikeCount": FieldValue.increment(Int64(1))
        ])
    }
    
    func reportPost(_ postId: String) async throws {
        try await db.collection("posts").document(postId).updateData([
            "reportCount": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Helper: Parse Post
    private func parsePost(from document: QueryDocumentSnapshot) -> Post? {
        let data = document.data()
        
        guard let userId = data["userId"] as? String,
              let content = data["content"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = Post.Category(rawValue: categoryRaw),
              let lat = data["latitude"] as? Double,
              let lon = data["longitude"] as? Double else {
            return nil
        }
        
        return Post(
            id: document.documentID,
            userId: userId,
            content: content,
            category: category,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
            likeCount: data["likeCount"] as? Int ?? 0,
            dislikeCount: data["dislikeCount"] as? Int ?? 0,
            reportCount: data["reportCount"] as? Int ?? 0,
            status: Post.Status(rawValue: data["status"] as? String ?? "active") ?? .active
        )
    }
    
    func stopListening() {
        userPostsListener?.remove()
        allPostsListener?.remove()
    }
}
