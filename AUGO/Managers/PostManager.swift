// PostManager.swift
import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class PostManager: ObservableObject {
    @Published var userPosts: [Post] = []
    @Published var allPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var userPostsListener: ListenerRegistration?
    private var allPostsListener: ListenerRegistration?
    
    deinit {
        userPostsListener?.remove()
        allPostsListener?.remove()
    }
    
    // MARK: - Create Post
    func createPost(content: String, category: Post.PostCategory, userId: String) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        do {
            let post = Post(
                userId: userId,
                content: content,
                category: category
            )
            
            // Convert to dictionary manually to avoid @DocumentID encoding issues
            let data: [String: Any] = [
                "userId": post.userId,
                "date": post.date,
                "content": post.content,
                "category": post.category.rawValue,
                "likeCount": post.likeCount,
                "dislikeCount": post.dislikeCount,
                "reportCount": post.reportCount,
                "status": post.status.rawValue
            ]
            
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
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error fetching user posts: \(error)")
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No posts found")
                        self.userPosts = []
                        return
                    }
                    
                    print("✅ Fetched \(documents.count) user posts")
                    
                    self.userPosts = documents.compactMap { document in
                        self.parsePost(from: document)
                    }
                }
            }
    }
    
    // MARK: - Fetch All Posts (Real-time)
    func fetchAllPosts() {
        allPostsListener?.remove()
        
        allPostsListener = db.collection("posts")
            .whereField("status", isEqualTo: "active")
            .order(by: "date", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error fetching all posts: \(error)")
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No posts found")
                        self.allPosts = []
                        return
                    }
                    
                    print("✅ Fetched \(documents.count) posts")
                    
                    self.allPosts = documents.compactMap { document in
                        self.parsePost(from: document)
                    }
                }
            }
    }
    
    // MARK: - Delete Post
    func deletePost(_ postId: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await db.collection("posts").document(postId).delete()
            print("✅ Post deleted successfully")
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Update Post
    func updatePost(_ postId: String, content: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await db.collection("posts").document(postId).updateData([
                "content": content
            ])
            print("✅ Post updated successfully")
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Like/Dislike
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
    
    // MARK: - Report Post
    func reportPost(_ postId: String) async throws {
        try await db.collection("posts").document(postId).updateData([
            "reportCount": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Helper: Parse Post from Firestore
    private func parsePost(from document: QueryDocumentSnapshot) -> Post? {
        let data = document.data()
        
        guard let userId = data["userId"] as? String,
              let content = data["content"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = Post.PostCategory(rawValue: categoryRaw) else {
            print("⚠️ Missing required fields for post: \(document.documentID)")
            return nil
        }
        
        let post = Post(
            id: document.documentID,
            userId: userId,
            date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
            content: content,
            category: category,
            likeCount: data["likeCount"] as? Int ?? 0,
            dislikeCount: data["dislikeCount"] as? Int ?? 0,
            reportCount: data["reportCount"] as? Int ?? 0,
            status: Post.PostStatus(rawValue: data["status"] as? String ?? "active") ?? .active
        )
        
        return post
    }
    
    // MARK: - Stop Listening
    func stopListening() {
        userPostsListener?.remove()
        allPostsListener?.remove()
    }
}
