import SwiftUI
import FirebaseAuth
import Combine

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var postManager: PostManager // Shared global instance

    @State private var notificationsOn = true
    @State private var showLogoutAlert = false
    @State private var userRank: Int = 0
    @State private var showDeleteAlert = false
    @State private var postToDelete: Post?
    
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
            Color.Brand.primary.opacity(0.06).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Avatar + Name Section
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.Brand.primary.opacity(0.2))
                                .frame(width: 96, height: 96)
                            
                            Text(String(userName.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color.Brand.primary)
                        }

                        Text(userName).font(.title3.weight(.bold))
                        Text(fullName).font(.subheadline).foregroundColor(.gray)
                        Text("Student ID: \(studentID)").font(.footnote).foregroundColor(.gray)
                        Text(faculty).font(.caption).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // MARK: - Stats Cards
                    HStack(spacing: 16) {
                        ProfileStatCard(title: "Total Points", value: "\(totalPoints)")
                        ProfileStatCard(title: "Rank", value: userRank > 0 ? "#\(userRank)" : "...")
                    }
                    .padding(.horizontal, 16)

                    // MARK: - Today's Posts Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Today Post")

                        if postManager.userPosts.isEmpty {
                            Text("No posts yet. Create your first post!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            // We use the ID as the identifier to ensure SwiftUI tracks deletions correctly
                            ForEach(postManager.userPosts) { post in
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

                    // MARK: - Captured Characters Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Captured Characters")

                        Text("Your collection of characters")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                CapturedCharacterCard(name: "Foxy", price: "75 coins")
                                // Add more cards here if available in your data model
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // MARK: - Settings Section
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

                    // MARK: - Logout Button
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
        .onAppear {
            authManager.fetchUserRank { rank in self.userRank = rank }
            if let userId = authManager.user?.uid {
                postManager.fetchUserPosts(userId: userId)
            }
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) { authManager.signOut() }
        }
        .alert("Delete Post", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    Task {
                        await performDelete(post)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this post?")
        }
    }
    
    // Explicit delete function to ensure synchronization
    private func performDelete(_ post: Post) async {
        guard let postId = post.id else { return }
        do {
            try await postManager.deletePost(postId)
            // The Firebase listener in PostManager should automatically update 'userPosts'
            // resulting in a UI refresh.
        } catch {
            print("❌ Delete error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Reusable UI Components

struct SectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color.Brand.primary)
    }
}

struct ProfileStatCard: View {
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
        .background(Color.Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct TodayPostCard: View {
    let post: Post
    let onDelete: () -> Void
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: post.date, relativeTo: Date())
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
        case .casual: return "bolt.heart"
        case .lostFound: return "magnifyingglass"
        case .complaint: return "exclamationmark.triangle"
        case .event: return "calendar"
        case .question: return "questionmark.circle"
        case .announcement: return "megaphone"
        case .arChallenge: return "arkit"
        }
    }
}

struct CapturedCharacterCard: View {
    let name: String
    let price: String
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(UIColor.systemGray6)
                Image(name) // Ensure "Foxy" exists in Assets.xcassets
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            }
            .frame(height: 130)
            .clipShape(RoundedCorner(radius: 14, corners: [.topLeft, .topRight]))

            ZStack {
                Color.white
                Text("\(name) · \(price)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .frame(height: 40)
            .clipShape(RoundedCorner(radius: 14, corners: [.bottomLeft, .bottomRight]))
        }
        .frame(width: 150)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
    }
}

// Helper for corner clipping
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
