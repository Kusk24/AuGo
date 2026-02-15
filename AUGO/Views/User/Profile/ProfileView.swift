import SwiftUI
import FirebaseAuth
import FirebaseCore

struct ProfileView: View {
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var showLogoutAlert = false
    @State private var userRank: Int = 0
    @State private var showDeleteAlert = false
    @State private var postToDelete: Post?
    @State private var errorMessage: String?
    @State private var showEconomyAlert = false
    @State private var economyAlertMessage = ""
    
    // Computed properties for real user data
    private var userName: String {
        authManager.userProfile?.nickname ?? "User"
    }
    
    private var fullName: String {
        authManager.userProfile?.name ?? "N/A"
    }
    
    private var studentID: String {
        authManager.userProfile?.studentID ?? "N/A"
    }
    
    private var faculty: String {
        authManager.userProfile?.faculty ?? "N/A"
    }
    
    private var totalPoints: Int {
        authManager.userProfile?.score ?? 0
    }
    
    private var coinBalance: Double {
        postManager.userEconomy?.coinBalance ?? authManager.userProfile?.coinBalance ?? 0
    }
    
    private var freePostsLeft: Int {
        postManager.userEconomy?.freePostsLeft ?? 0
    }
    
    private var dailyFreePostLimit: Int {
        postManager.userEconomy?.dailyFreePostLimit ?? 0
    }
    
    private var canClaimDailyCoin: Bool {
        postManager.userEconomy?.canClaimDailyCoin ?? false
    }
    
    private var dailyCoinReward: Double {
        postManager.userEconomy?.dailyCoinReward ?? 0
    }
    
    private var todayPosts: [Post] {
        postManager.userPosts
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    private var capturedCharacters: [ARCapturedCharacter] {
        (authManager.userProfile?.arCapturedCharacters ?? [])
            .sorted { ($0.lastCapturedAt ?? .distantPast) > ($1.lastCapturedAt ?? .distantPast) }
    }

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Avatar + name
                    VStack(spacing: 12) {
                        // Avatar with initials
                        ZStack {
                            Circle()
                                .fill(Color.Brand.primary.opacity(0.2))
                                .frame(width: 96, height: 96)
                            
                            Text(String(userName.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color.Brand.primary)
                        }

                        Text(userName)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text(fullName)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Text("Student ID: \(studentID)")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        
                        Text(faculty)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // MARK: Stats cards
                    HStack(spacing: 16) {
                        ProfileStatCard(
                            title: "Total Points",
                            value: "\(totalPoints)"
                        )

                        ProfileStatCard(
                            title: "Rank",
                            value: userRank > 0 ? "#\(userRank)" : "..."
                        )
                    }
                    .padding(.horizontal, 16)
                    .onAppear {
                        // Fetch rank when view appears
                        authManager.fetchUserRank { rank in
                            userRank = rank
                        }
                        
                        // Fetch user posts with real-time listener
                        if let userId = authManager.user?.uid {
                            print("👤 Setting up real-time listener for user posts: \(userId)")
                            postManager.fetchUserPosts(userId: userId)
                            authManager.fetchUserProfile(uid: userId)
                            Task {
                                await postManager.refreshUserEconomy(userId: userId)
                            }
                        }
                    }
                    
                    // MARK: Coins & Daily Posts
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("Coins")
                        
                        Text("Points and coins are separate.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            EconomyInfoCard(
                                title: "Coin Balance",
                                value: coinsText(coinBalance),
                                icon: "bitcoinsign.circle.fill"
                            )
                            EconomyInfoCard(
                                title: "Free Posts Left",
                                value: "\(freePostsLeft)/\(dailyFreePostLimit)",
                                icon: "square.and.pencil"
                            )
                        }
                        
                        Button {
                            guard let userId = authManager.user?.uid else { return }
                            Task {
                                do {
                                    let message = try await postManager.claimDailyLoginCoin(userId: userId)
                                    economyAlertMessage = message
                                    showEconomyAlert = true
                                } catch {
                                    economyAlertMessage = "Failed to claim daily coin: \(error.localizedDescription)"
                                    showEconomyAlert = true
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "gift.fill")
                                Text(canClaimDailyCoin ? "Claim Daily +\(coinsText(dailyCoinReward)) Coins" : "Daily Coin Already Claimed")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(canClaimDailyCoin ? Color.Brand.primary : Color.gray.opacity(0.25))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!canClaimDailyCoin)
                    }
                    .padding(.horizontal, 16)

                    // MARK: Today Post
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Today Posts")

                        if postManager.isUserPostsLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Loading your posts...")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        } else if todayPosts.isEmpty {
                            Text("No posts yet. Create your first post!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(todayPosts.enumerated()), id: \.offset) { _, post in
                                    TodayPostCard(
                                        post: post,
                                        onDelete: {
                                            postToDelete = post
                                            showDeleteAlert = true
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // MARK: Captured Characters
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Captured Characters")

                        Text("Your collection of characters")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        if capturedCharacters.isEmpty {
                            Text("No captures yet. Catch AR characters to see them here.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(capturedCharacters) { capture in
                                        CapturedCharacterCard(capture: capture)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // MARK: Settings
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Settings")

                        Text("Manage your account preferences here.")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        HStack {
                            Text("Notification Preferences")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { notificationManager.notificationsEnabled },
                                set: { notificationManager.setNotificationsEnabled($0) }
                            ))
                                .labelsHidden()
                                .tint(Color.Brand.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray6))
                        )
                    }
                    .padding(.horizontal, 16)

                    // MARK: Logout button
                    Button {
                        showLogoutAlert = true
                    } label: {
                        Text("Logout")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Delete Post", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    Task {
                        await deletePost(post)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this post?")
        }
        .alert("Coins", isPresented: $showEconomyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(economyAlertMessage)
        }
        .onChange(of: authManager.user?.uid) { _, newUserId in
            // Re-setup listener if user changes
            if let userId = newUserId {
                print("👤 User changed, re-setting up listener: \(userId)")
                postManager.fetchUserPosts(userId: userId)
                authManager.fetchUserProfile(uid: userId)
                Task {
                    await postManager.refreshUserEconomy(userId: userId)
                }
            }
        }
    }
    
    // MARK: - Delete Post
    private func deletePost(_ post: Post) async {
        guard let postId = post.id else { 
            print("❌ Cannot delete post: missing ID")
            return 
        }
        
        print("🗑️ Attempting to delete post: \(postId)")
        
        // Optimistic update - remove from UI immediately
        postManager.optimisticDeletePost(postId)
        
        do {
            try await postManager.deletePost(postId)
            print("✅ Post deleted successfully: \(postId)")
            // The real-time listener will keep everything in sync
        } catch {
            print("❌ Error deleting post: \(error.localizedDescription)")
            errorMessage = "Failed to delete post: \(error.localizedDescription)"
            // Re-fetch to restore the post if deletion failed
            if let userId = authManager.user?.uid {
                postManager.fetchUserPosts(userId: userId)
            }
        }
    }
}

private func coinsText(_ value: Double) -> String {
    String(format: "%.1f", value)
}

// MARK: - Reusable bits

private struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color.Brand.primary)
    }
}

private struct ProfileStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.9))

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.Brand.coin)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct EconomyInfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Color.Brand.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        )
    }
}

private struct TodayPostCard: View {
    let post: Post
    let onDelete: () -> Void
    
    private var timeAgo: String {
        let interval = Date().timeIntervalSince(post.date)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if days > 0 {
            return "Posted \(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "Posted \(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let minutes = max(1, Int(interval / 60))
            return "Posted \(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }
    }

    private var firstPhotoURL: URL? {
        guard let photoPath = post.photoPaths.first else { return nil }
        guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let escapedPath = photoPath.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 12, height: 12)
                    
                    Text(post.category.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(categoryColor.opacity(0.14))
                )
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.85))
                        .font(.system(size: 16, weight: .bold))
                }
            }

            if let firstPhotoURL {
                AsyncImage(url: firstPhotoURL) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.systemGray5))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.systemGray5))
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text(post.content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            HStack {
                Text(timeAgo)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.systemGray6))
                    )
                
                Spacer()
                
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.purple)
                        Text("\(post.likeCount)")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.black)
                        Text("\(post.dislikeCount)")
                            .font(.subheadline)
                    }
                }
            }            
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
        )
    }
    
    private var categoryColor: Color {
        switch post.category {
        case .casual:
            return .yellow
        case .event:
            return .orange
        case .question:
            return .blue
        case .announcement:
            return .purple
        case .arChallenge:
            return .green
        }
    }
}

private struct CapturedCharacterCard: View {
    let capture: ARCapturedCharacter

    private var previewURL: URL? {
        guard let previewPath = capture.preview else { return nil }
        guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let escapedPath = previewPath.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
    }

    private var footerText: String {
        if capture.catchCount >= capture.catchableTime {
            return "Maxed · +\(coinsText(capture.coinValue)) coins · +\(capture.pointValue) pts"
        }
        if let next = capture.nextCatchAt, next > Date() {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Next in \(formatter.localizedString(for: next, relativeTo: Date()))"
        }
        return "Ready again · +\(coinsText(capture.coinValue)) coins · +\(capture.pointValue) pts"
    }

    private var progress: Double {
        guard capture.catchableTime > 0 else { return 1 }
        return min(1, Double(capture.catchCount) / Double(capture.catchableTime))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.Brand.primary.opacity(0.18), Color.Brand.primary.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let previewURL {
                    AsyncImage(url: previewURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                        case .failure:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
            }
            .frame(height: 135)

            Text(capture.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text("\(capture.catchCount)/\(capture.catchableTime) captured")
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView(value: progress)
                .tint(Color.Brand.primary)

            Text(footerText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.Brand.primary.opacity(0.18))
                    .frame(width: 54, height: 54)
                Text(String(capture.title.prefix(1)).uppercased())
                    .font(.title3.weight(.bold))
                    .foregroundColor(Color.Brand.primary)
            }

            Text("Preview not added")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
