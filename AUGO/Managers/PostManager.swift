// PostManager.swift
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
    
    init() {
        // Start listening for all posts immediately when manager is created
        print("🚀 PostManager initialized - starting real-time listener")
        // Use fallback query by default (doesn't require compound index)
        fetchAllPostsSimple()
    }
    
    deinit {
        userPostsListener?.remove()
        allPostsListener?.remove()
    }
    
    // MARK: - Create Post
    func createPost(content: String, category: Post.PostCategory, userId: String, coordinate: CLLocationCoordinate2D) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        do {
            let post = Post(
                userId: userId,
                content: content,
                category: category,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            
            // Convert to dictionary manually to avoid @DocumentID encoding issues
            let data: [String: Any] = [
                "userId": post.userId,
                "date": post.date,
                "content": post.content,
                "category": post.category.rawValue,
                "latitude": post.latitude,
                "longitude": post.longitude,
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
    
    // MARK: - Fetch All Posts (Real-time - Last 24 hours only)
    func fetchAllPosts() {
        // Remove existing listener before creating a new one
        allPostsListener?.remove()
        
        print("🔄 Starting to fetch all posts...")
        print("🔍 Device: \(UIDevice.current.name)")
        
        // Calculate 24 hours ago
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        print("⏰ Fetching posts newer than: \(twentyFourHoursAgo)")
        
        // Try with 24-hour filter first
        allPostsListener = db.collection("posts")
            .whereField("status", isEqualTo: "active")
            .whereField("date", isGreaterThan: Timestamp(date: twentyFourHoursAgo))
            .order(by: "date", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        let errorMsg = error.localizedDescription
                        print("❌ Error fetching posts with 24h filter: \(errorMsg)")
                        
                        // If it's an index error, try fallback query
                        if errorMsg.contains("index") || errorMsg.contains("requires an index") {
                            print("⚠️ Index not found, using fallback query (all active posts)")
                            self.fetchAllPostsFallback()
                            return
                        }
                        
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No documents in snapshot")
                        self.allPosts = []
                        return
                    }
                    
                    print("✅ Fetched \(documents.count) posts from last 24 hours")
                    print("📱 Device: \(UIDevice.current.name)")
                    
                    let parsed = documents.compactMap { document in
                        self.parsePost(from: document)
                    }
                    
                    print("✅ Successfully parsed \(parsed.count) posts")
                    
                    if !parsed.isEmpty {
                        print("📍 Sample posts:")
                        for (index, post) in parsed.prefix(3).enumerated() {
                            print("   \(index + 1). '\(post.content)' at (\(post.latitude), \(post.longitude)) - \(post.date)")
                        }
                    }
                    
                    self.allPosts = parsed
                    
                    if parsed.isEmpty && !documents.isEmpty {
                        print("⚠️ WARNING: Documents exist but parsing failed!")
                        print("⚠️ First document data: \(documents.first?.data() ?? [:])")
                    }
                }
            }
    }
    
    // MARK: - Fallback: Fetch All Active Posts (no time filter)
    private func fetchAllPostsFallback() {
        allPostsListener?.remove()
        
        print("🔄 Using fallback: Fetching all active posts without time filter")
        print("📱 Device: \(UIDevice.current.name)")
        
        allPostsListener = db.collection("posts")
            .whereField("status", isEqualTo: "active")
            .order(by: "date", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ Fallback query also failed: \(error)")
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No documents in fallback snapshot")
                        self.allPosts = []
                        return
                    }
                    
                    print("✅ Fallback: Fetched \(documents.count) active posts")
                    print("📱 Device: \(UIDevice.current.name)")
                    
                    // Filter to last 24 hours client-side
                    let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
                    
                    let parsed = documents.compactMap { document -> Post? in
                        guard let post = self.parsePost(from: document) else { return nil }
                        // Client-side filter for 24 hours
                        return post.date > twentyFourHoursAgo ? post : nil
                    }
                    
                    print("✅ After 24h filter: \(parsed.count) posts")
                    
                    if !parsed.isEmpty {
                        print("📍 Sample posts:")
                        for (index, post) in parsed.prefix(3).enumerated() {
                            print("   \(index + 1). '\(post.content)' at (\(post.latitude), \(post.longitude)) - \(post.date)")
                        }
                    }
                    
                    self.allPosts = parsed
                }
            }
    }
    
    // MARK: - Fetch All Posts (Simple - No compound index needed)
    func fetchAllPostsSimple() {
        allPostsListener?.remove()
        
        print("🔄 Fetching all active posts (simple query)...")
        print("📱 Device: \(UIDevice.current.name)")
        
        // Simple query that doesn't require compound index
        allPostsListener = db.collection("posts")
            .whereField("status", isEqualTo: "active")
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error fetching posts: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No documents in snapshot")
                        self.allPosts = []
                        return
                    }
                    
                    print("✅ Fetched \(documents.count) documents from Firestore")
                    
                    // Parse all posts
                    let allParsed = documents.compactMap { document in
                        self.parsePost(from: document)
                    }
                    
                    print("✅ Successfully parsed \(allParsed.count) posts")
                    
                    // Filter to last 24 hours client-side
                    let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
                    let filtered = allParsed.filter { $0.date > twentyFourHoursAgo }
                    
                    print("✅ After 24h filter: \(filtered.count) posts")
                    
                    if !filtered.isEmpty {
                        print("📍 Sample posts:")
                        for (index, post) in filtered.prefix(3).enumerated() {
                            print("   \(index + 1). '\(post.content)' at (\(post.latitude), \(post.longitude)) - \(post.date)")
                        }
                    } else if !allParsed.isEmpty {
                        print("⚠️ Posts exist but all are older than 24 hours")
                        print("📅 Oldest post: \(allParsed.map { $0.date }.min() ?? Date())")
                        print("📅 Newest post: \(allParsed.map { $0.date }.max() ?? Date())")
                    }
                    
                    // Sort by date descending
                    self.allPosts = filtered.sorted { $0.date > $1.date }
                    
                    if allParsed.isEmpty && !documents.isEmpty {
                        print("⚠️ WARNING: Documents exist but parsing failed!")
                        print("⚠️ First document data: \(documents.first?.data() ?? [:])")
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
    
    // MARK: - Like/Dislike with Reaction Tracking
    
    // Check if user has reacted to a post
    func getUserReaction(postId: String, userId: String) async throws -> String? {
        let reactionDoc = try await db.collection("user_reactions")
            .document("\(userId)_\(postId)")
            .getDocument()
        
        if reactionDoc.exists {
            return reactionDoc.data()?["reaction"] as? String
        }
        return nil
    }
    
    // Like a post (removes dislike if exists, toggles like)
    func likePost(_ postId: String, userId: String) async throws {
        let reactionId = "\(userId)_\(postId)"
        let reactionRef = db.collection("user_reactions").document(reactionId)
        let reactionDoc = try await reactionRef.getDocument()
        
        if let existingReaction = reactionDoc.data()?["reaction"] as? String {
            if existingReaction == "like" {
                // User already liked, remove like
                try await reactionRef.delete()
                try await db.collection("posts").document(postId).updateData([
                    "likeCount": FieldValue.increment(Int64(-1))
                ])
                print("❤️ Removed like from post \(postId)")
            } else {
                // User disliked, change to like
                try await reactionRef.updateData(["reaction": "like"])
                try await db.collection("posts").document(postId).updateData([
                    "likeCount": FieldValue.increment(Int64(1)),
                    "dislikeCount": FieldValue.increment(Int64(-1))
                ])
                print("❤️ Changed dislike to like on post \(postId)")
            }
        } else {
            // No reaction yet, add like
            try await reactionRef.setData([
                "userId": userId,
                "postId": postId,
                "reaction": "like",
                "timestamp": Timestamp(date: Date())
            ])
            try await db.collection("posts").document(postId).updateData([
                "likeCount": FieldValue.increment(Int64(1))
            ])
            print("❤️ Added like to post \(postId)")
        }
    }
    
    // Dislike a post (removes like if exists, toggles dislike)
    func dislikePost(_ postId: String, userId: String) async throws {
        let reactionId = "\(userId)_\(postId)"
        let reactionRef = db.collection("user_reactions").document(reactionId)
        let reactionDoc = try await reactionRef.getDocument()
        
        if let existingReaction = reactionDoc.data()?["reaction"] as? String {
            if existingReaction == "dislike" {
                // User already disliked, remove dislike
                try await reactionRef.delete()
                try await db.collection("posts").document(postId).updateData([
                    "dislikeCount": FieldValue.increment(Int64(-1))
                ])
                print("👎 Removed dislike from post \(postId)")
            } else {
                // User liked, change to dislike
                try await reactionRef.updateData(["reaction": "dislike"])
                try await db.collection("posts").document(postId).updateData([
                    "dislikeCount": FieldValue.increment(Int64(1)),
                    "likeCount": FieldValue.increment(Int64(-1))
                ])
                print("👎 Changed like to dislike on post \(postId)")
            }
        } else {
            // No reaction yet, add dislike
            try await reactionRef.setData([
                "userId": userId,
                "postId": postId,
                "reaction": "dislike",
                "timestamp": Timestamp(date: Date())
            ])
            try await db.collection("posts").document(postId).updateData([
                "dislikeCount": FieldValue.increment(Int64(1))
            ])
            print("👎 Added dislike to post \(postId)")
        }
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
              let categoryRawAny = data["category"],
              let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double else {
            print("⚠️ Missing required fields for post: \(document.documentID) -> \(data)")
            return nil
        }

        // Normalize category (handle different casings or accidental non-string values)
        let categoryRaw: String
        if let catStr = categoryRawAny as? String {
            // Capitalize first letter to match Post.PostCategory rawValue format
            categoryRaw = catStr.prefix(1).uppercased() + catStr.dropFirst().lowercased()
        } else {
            let str = String(describing: categoryRawAny)
            categoryRaw = str.prefix(1).uppercased() + str.dropFirst().lowercased()
        }
        
        guard let category = Post.PostCategory(rawValue: categoryRaw) else {
            print("⚠️ Unknown category '\(categoryRawAny)' (normalized: '\(categoryRaw)') for post: \(document.documentID). Falling back to .casual")
            // Fall back to a sensible default to avoid dropping the post entirely
            let fallbackCategory: Post.PostCategory = .casual
            let post = Post(
                id: document.documentID,
                userId: userId,
                date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
                content: content,
                category: fallbackCategory,
                latitude: latitude,
                longitude: longitude,
                likeCount: data["likeCount"] as? Int ?? 0,
                dislikeCount: data["dislikeCount"] as? Int ?? 0,
                reportCount: data["reportCount"] as? Int ?? 0,
                status: Post.PostStatus(rawValue: data["status"] as? String ?? "active") ?? .active
            )
            return post
        }

        // Safely parse date (Timestamp or Date), otherwise default to now so it still appears
        let parsedDate: Date
        if let ts = data["date"] as? Timestamp {
            parsedDate = ts.dateValue()
        } else if let dt = data["date"] as? Date {
            parsedDate = dt
        } else {
            print("⚠️ Missing/invalid date for post: \(document.documentID). Defaulting to now(). Raw: \(String(describing: data["date"]))")
            parsedDate = Date()
        }

        let post = Post(
            id: document.documentID,
            userId: userId,
            date: parsedDate,
            content: content,
            category: category,
            latitude: latitude,
            longitude: longitude,
            likeCount: data["likeCount"] as? Int ?? 0,
            dislikeCount: data["dislikeCount"] as? Int ?? 0,
            reportCount: data["reportCount"] as? Int ?? 0,
            status: Post.PostStatus(rawValue: data["status"] as? String ?? "active") ?? .active
        )

        return post
    }
    
    // MARK: - Report Post
    func reportPost(_ postId: String, category: Report.ReportCategory, reportedBy userId: String, reporterName: String, post: Post) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🚨 Starting report for post: \(postId)")
            
            // Fetch the reported user's information
            let reportedUserDoc = try await db.collection("users").document(post.userId).getDocument()
            let reportedUserName = reportedUserDoc.data()?["name"] as? String ?? "Unknown User"
            
            print("🚨 Reported user: \(reportedUserName), Reporter: \(reporterName)")
            
            // Get description based on category
            let description: String
            switch category {
            case .spam:
                description = "Selling products, inappropriate, suspicious links"
            case .harassment:
                description = "Bullying, threatening, or harassing content"
            case .inappropriate:
                description = "Offensive, explicit, or inappropriate content"
            case .misinformation:
                description = "False or misleading information"
            case .other:
                description = "Other violations of community guidelines"
            }
            
            // Create new report document (each report is a separate document)
            // Admins can see all reports and aggregate by postId
            let reportData: [String: Any] = [
                "category": category.rawValue,
                "description": description,
                "postContent": post.content,
                "postId": postId,
                "reportCount": 1,
                "reportDate": Timestamp(date: Date()),
                "reported": [
                    "id": post.userId,
                    "name": reportedUserName
                ],
                "reporter": [
                    "id": userId,
                    "name": reporterName
                ],
                "status": Report.ReportStatus.pending.rawValue,
                "updatedAt": Timestamp(date: Date())
            ]
            
            try await db.collection("reports").addDocument(data: reportData)
            print("✅ New report created for post: \(postId)")
            
            // Update post's report count
            try await db.collection("posts").document(postId).updateData([
                "reportCount": FieldValue.increment(Int64(1))
            ])
            print("✅ Post report count incremented")
            
            isLoading = false
        } catch {
            print("❌ Error reporting post: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Stop Listening
    func stopListening() {
        userPostsListener?.remove()
        allPostsListener?.remove()
    }
}

