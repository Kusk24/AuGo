// PostManager.swift
import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

@MainActor
class PostManager: ObservableObject {
    struct AdminConfiguration {
        let dailyFreePostLimit: Int
        let dailyFreeCoin: Int
        let postVisibilityDurationHours: Int
        
        static let `default` = AdminConfiguration(
            dailyFreePostLimit: 3,
            dailyFreeCoin: 10,
            postVisibilityDurationHours: 24
        )
    }
    
    struct UserEconomySnapshot {
        let coinBalance: Int
        let dailyPostsUsed: Int
        let dailyFreePostLimit: Int
        let freePostsLeft: Int
        let dailyCoinReward: Int
        let canClaimDailyCoin: Bool
    }
    
    enum PostCreationError: LocalizedError {
        case insufficientCoins(required: Int, balance: Int)
        
        var errorDescription: String? {
            switch self {
            case let .insufficientCoins(required, balance):
                return "Not enough coins. Need \(required), current balance is \(balance)."
            }
        }
    }
    
    @Published var userPosts: [Post] = []
    @Published var allPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastPostCreationMessage: String?
    @Published var userEconomy: UserEconomySnapshot?
    
    private let db = Firestore.firestore()
    private var userPostsListener: ListenerRegistration?
    private var allPostsListener: ListenerRegistration?
    private var adminConfigCache: AdminConfiguration = .default
    private var lastAdminConfigFetch: Date?
    
    init() {
        // Start listening for all posts immediately when manager is created
        print("🚀 PostManager initialized - starting real-time listener")
        // Use fallback query by default (doesn't require compound index)
        fetchAllPostsSimple()
        
        Task { [weak self] in
            await self?.bootstrapAdminConfiguration()
        }
    }
    
    deinit {
        userPostsListener?.remove()
        allPostsListener?.remove()
    }
    
    private func bootstrapAdminConfiguration() async {
        _ = await loadAdminConfiguration(forceRefresh: true)
        fetchAllPostsSimple()
    }
    
    private func loadAdminConfiguration(forceRefresh: Bool = false) async -> AdminConfiguration {
        if !forceRefresh,
           let lastFetch = lastAdminConfigFetch,
           Date().timeIntervalSince(lastFetch) < 300 {
            return adminConfigCache
        }
        
        do {
            let snapshot = try await db.collection("admin_configuration").document("default").getDocument()
            guard let data = snapshot.data() else {
                adminConfigCache = .default
                lastAdminConfigFetch = Date()
                return adminConfigCache
            }
            
            adminConfigCache = AdminConfiguration(
                dailyFreePostLimit: max(0, data["dailyFreePostLimit"] as? Int ?? AdminConfiguration.default.dailyFreePostLimit),
                dailyFreeCoin: max(0, data["dailyFreeCoin"] as? Int ?? AdminConfiguration.default.dailyFreeCoin),
                postVisibilityDurationHours: max(1, data["postVisibilityDuration"] as? Int ?? AdminConfiguration.default.postVisibilityDurationHours)
            )
            lastAdminConfigFetch = Date()
            return adminConfigCache
        } catch {
            print("⚠️ Failed to load admin configuration. Using defaults: \(error.localizedDescription)")
            adminConfigCache = .default
            lastAdminConfigFetch = Date()
            return adminConfigCache
        }
    }
    
    private func currentVisibilityCutoffDate() -> Date {
        let hours = adminConfigCache.postVisibilityDurationHours
        return Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
    }
    
    private func startOfToday(_ date: Date = Date()) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    private func isSameDay(_ lhs: Date?, _ rhs: Date) -> Bool {
        guard let lhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
    
    private func normalizedDailyPostCount(rawCount: Int, rawDate: Date?, now: Date) -> Int {
        isSameDay(rawDate, now) ? rawCount : 0
    }
    
    func refreshUserEconomy(userId: String) async {
        let config = await loadAdminConfiguration()
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            let data = snapshot.data() ?? [:]
            
            let now = Date()
            let coinBalance = data["coinBalance"] as? Int ?? 0
            let rawDailyPostCount = data["dailyPostCount"] as? Int ?? 0
            let dailyPostCountDate = (data["dailyPostCountDate"] as? Timestamp)?.dateValue()
            let lastCoinGrantDate = (data["lastCoinGrantDate"] as? Timestamp)?.dateValue()
            
            let todayPostCount = normalizedDailyPostCount(
                rawCount: rawDailyPostCount,
                rawDate: dailyPostCountDate,
                now: now
            )
            
            let freePostsLeft = max(0, config.dailyFreePostLimit - todayPostCount)
            let canClaimDailyCoin = !isSameDay(lastCoinGrantDate, now)
            
            userEconomy = UserEconomySnapshot(
                coinBalance: coinBalance,
                dailyPostsUsed: todayPostCount,
                dailyFreePostLimit: config.dailyFreePostLimit,
                freePostsLeft: freePostsLeft,
                dailyCoinReward: config.dailyFreeCoin,
                canClaimDailyCoin: canClaimDailyCoin
            )
        } catch {
            print("❌ Failed to refresh user economy: \(error.localizedDescription)")
        }
    }
    
    @discardableResult
    func claimDailyLoginCoin(userId: String) async throws -> String {
        let config = await loadAdminConfiguration(forceRefresh: true)
        let now = Date()
        let startOfDay = startOfToday(now)
        let userRef = db.collection("users").document(userId)
        
        let result = try await db.runTransaction { transaction, errorPointer in
            let userSnapshot: DocumentSnapshot
            do {
                userSnapshot = try transaction.getDocument(userRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            
            let userData = userSnapshot.data() ?? [:]
            let coinBalance = userData["coinBalance"] as? Int ?? 0
            let lastCoinGrantDate = (userData["lastCoinGrantDate"] as? Timestamp)?.dateValue()
            
            if self.isSameDay(lastCoinGrantDate, now) {
                return "Daily coin already claimed today."
            }
            
            let newBalance = coinBalance + config.dailyFreeCoin
            transaction.setData([
                "coinBalance": newBalance,
                "lastCoinGrantDate": Timestamp(date: startOfDay),
                "updatedAt": Timestamp(date: now)
            ], forDocument: userRef, merge: true)
            
            return "Claimed +\(config.dailyFreeCoin) coins. Balance: \(newBalance)."
        }
        
        let message = (result as? String) ?? "Daily coin claimed."
        lastPostCreationMessage = message
        
        await refreshUserEconomy(userId: userId)
        return message
    }
    
    // MARK: - Create Post
    func createPost(content: String, category: Post.PostCategory, userId: String, coordinate: CLLocationCoordinate2D) async throws -> String {
        isLoading = true
        errorMessage = nil
        lastPostCreationMessage = nil
        
        do {
            let adminConfig = await loadAdminConfiguration()
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let expiresAt = Calendar.current.date(
                byAdding: .hour,
                value: adminConfig.postVisibilityDurationHours,
                to: now
            ) ?? now
            
            let postRef = db.collection("posts").document()
            let userRef = db.collection("users").document(userId)
            var transactionMessage = "Post created successfully."
            
            let transactionResult = try await db.runTransaction { transaction, errorPointer in
                let userSnapshot: DocumentSnapshot
                do {
                    userSnapshot = try transaction.getDocument(userRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                
                let userData = userSnapshot.data() ?? [:]
                var coinBalance = userData["coinBalance"] as? Int ?? 0
                let rawDailyPostCount = userData["dailyPostCount"] as? Int ?? 0
                let dailyPostCountDate = (userData["dailyPostCountDate"] as? Timestamp)?.dateValue()
                var dailyPostCount = self.normalizedDailyPostCount(
                    rawCount: rawDailyPostCount,
                    rawDate: dailyPostCountDate,
                    now: now
                )
                
                let needsCoin = dailyPostCount >= adminConfig.dailyFreePostLimit
                if needsCoin && coinBalance < 1 {
                    errorPointer?.pointee = PostCreationError.insufficientCoins(required: 1, balance: coinBalance) as NSError
                    return nil
                }
                
                let spentCoin = needsCoin ? 1 : 0
                coinBalance -= spentCoin
                dailyPostCount += 1
                
                transaction.setData([
                    "coinBalance": coinBalance,
                    "dailyPostCount": dailyPostCount,
                    "dailyPostCountDate": Timestamp(date: startOfDay),
                    "updatedAt": Timestamp(date: now)
                ], forDocument: userRef, merge: true)
                
                let post = Post(
                    id: postRef.documentID,
                    userId: userId,
                    date: now,
                    content: content,
                    category: category,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    likeCount: 0,
                    dislikeCount: 0,
                    reportCount: 0,
                    status: .active
                )
                
                transaction.setData([
                    "userId": post.userId,
                    "date": post.date,
                    "expiresAt": Timestamp(date: expiresAt),
                    "content": post.content,
                    "category": post.category.rawValue,
                    "latitude": post.latitude,
                    "longitude": post.longitude,
                    "likeCount": post.likeCount,
                    "dislikeCount": post.dislikeCount,
                    "reportCount": post.reportCount,
                    "status": post.status.rawValue,
                    "coinSpent": spentCoin
                ], forDocument: postRef)
                
                if spentCoin > 0 {
                    transactionMessage = "Post created. -1 coin (Balance: \(coinBalance))."
                } else {
                    let freeUsed = min(dailyPostCount, adminConfig.dailyFreePostLimit)
                    transactionMessage = "Post created. Free posts today: \(freeUsed)/\(adminConfig.dailyFreePostLimit)."
                }
                
                return postRef.documentID
            }
            
            guard let postID = transactionResult as? String else {
                throw NSError(
                    domain: "PostManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create post."]
                )
            }
            
            lastPostCreationMessage = transactionMessage
            await refreshUserEconomy(userId: userId)
            isLoading = false
            return postID
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Fetch User Posts (Real-time)
    func fetchUserPosts(userId: String) {
        // Remove existing listener to avoid duplicates
        userPostsListener?.remove()
        
        print("🔄 Setting up real-time listener for user \(userId) posts")
        
        userPostsListener = db.collection("posts")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error fetching user posts: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No posts found for user \(userId)")
                        self.userPosts = []
                        return
                    }
                    
                    print("✅ Real-time update: Fetched \(documents.count) user posts")
                    
                    let parsed = documents.compactMap { document in
                        self.parsePost(from: document)
                    }
                    
                    print("✅ Successfully parsed \(parsed.count) posts for user")
                    self.userPosts = parsed
                    
                    // Print post IDs for debugging
                    if !parsed.isEmpty {
                        print("📝 Current user posts: \(parsed.map { $0.id ?? "no-id" }.joined(separator: ", "))")
                    }
                }
            }
    }
    
    // MARK: - Fetch All Posts (Real-time - Visibility duration)
    func fetchAllPosts() {
        // Remove existing listener before creating a new one
        allPostsListener?.remove()
        
        print("🔄 Starting to fetch all posts...")
        print("🔍 Device: \(UIDevice.current.name)")
        
        // Calculate visibility cutoff based on admin configuration
        let cutoffDate = currentVisibilityCutoffDate()
        print("⏰ Fetching posts newer than: \(cutoffDate)")
        
        // Try with 24-hour filter first
        allPostsListener = db.collection("posts")
            .whereField("status", isEqualTo: "active")
            .whereField("date", isGreaterThan: Timestamp(date: cutoffDate))
            .order(by: "date", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let error = error {
                        let errorMsg = error.localizedDescription
                        print("❌ Error fetching posts with visibility filter: \(errorMsg)")
                        
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
                    
                    print("✅ Fetched \(documents.count) visible posts")
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
                    
                    // Filter by configured visibility duration client-side
                    let cutoffDate = self.currentVisibilityCutoffDate()
                    
                    let parsed = documents.compactMap { document -> Post? in
                        guard let post = self.parsePost(from: document) else { return nil }
                        // Client-side filter for configurable visibility duration
                        return post.date > cutoffDate ? post : nil
                    }
                    
                    print("✅ After visibility filter: \(parsed.count) posts")
                    
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
                    
                    // Filter using configurable visibility duration
                    let cutoffDate = self.currentVisibilityCutoffDate()
                    let filtered = allParsed.filter { $0.date > cutoffDate }
                    
                    print("✅ After visibility filter: \(filtered.count) posts")
                    
                    if !filtered.isEmpty {
                        print("📍 Sample posts:")
                        for (index, post) in filtered.prefix(3).enumerated() {
                            print("   \(index + 1). '\(post.content)' at (\(post.latitude), \(post.longitude)) - \(post.date)")
                        }
                    } else if !allParsed.isEmpty {
                        print("⚠️ Posts exist but all are older than visibility duration")
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
    
    // MARK: - Optimistic Delete (instant UI update)
    func optimisticDeletePost(_ postId: String) {
        print("⚡ Optimistically removing post from UI: \(postId)")
        userPosts.removeAll { $0.id == postId }
        allPosts.removeAll { $0.id == postId }
        print("✅ Post removed from local arrays. Remaining user posts: \(userPosts.count)")
    }
    
    // MARK: - Delete Post
    func deletePost(_ postId: String) async throws {
        isLoading = true
        errorMessage = nil
        
        print("🗑️ Deleting post from Firestore: \(postId)")
        
        do {
            try await db.collection("posts").document(postId).delete()
            print("✅ Post deleted successfully from Firestore: \(postId)")
            print("📡 Real-time listeners will automatically update the UI")
            isLoading = false
        } catch {
            print("❌ Failed to delete post: \(error.localizedDescription)")
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
