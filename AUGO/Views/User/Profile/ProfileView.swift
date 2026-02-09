import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var postManager: PostManager

    @State private var notificationsOn = true
    @State private var showLogoutAlert = false
    @State private var userRank: Int = 0
    @State private var showDeleteAlert = false
    @State private var postToDelete: Post?
    @State private var errorMessage: String?
    
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
                        }
                    }

                    // MARK: Today Post
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Today Post")

                        if postManager.userPosts.isEmpty {
                            Text("No posts yet. Create your first post!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(postManager.userPosts.prefix(3)) { post in
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
                    .padding(.horizontal, 16)

                    // MARK: Captured Characters
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Captured Characters")

                        Text("Your collection of characters")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        CapturedCharacterCard()
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

                            Toggle("", isOn: $notificationsOn)
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
        .onChange(of: authManager.user?.uid) { newUserId in
            // Re-setup listener if user changes
            if let userId = newUserId {
                print("👤 User changed, re-setting up listener: \(userId)")
                postManager.fetchUserPosts(userId: userId)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.Brand.primary.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: iconForCategory)
                            .foregroundColor(Color.Brand.primary)
                            .font(.system(size: 14, weight: .semibold))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.primary)

                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.system(size: 14, weight: .semibold))
                }
            }

            Text(post.content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                    Text("\(post.likeCount)")
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                    Text("\(post.dislikeCount)")
                }
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
        )
    }
    
    private var iconForCategory: String {
        switch post.category {
        case .casual:
            return "bolt.heart"
        case .event:
            return "calendar"
        case .question:
            return "questionmark.circle"
        case .announcement:
            return "megaphone"
        case .arChallenge:
            return "arkit"
        }
    }
}

import SwiftUI

private struct CapturedCharacterCard: View {
    var body: some View {
        VStack(spacing: 0) {

            // TOP
            ZStack {
                Color(UIColor.systemGray6)

                Image("Foxy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            }
            .frame(height: 130)
            .clipShape(
                RoundedCorner(radius: 14, corners: [.topLeft, .topRight])
            )

            // BOTTOM
            ZStack {
                Color(.white)

                Text("Fox · 75 coins")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .frame(height: 40)
            .clipShape(
                RoundedCorner(radius: 14, corners: [.bottomLeft, .bottomRight])
            )
        }
        .frame(width: 150)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
