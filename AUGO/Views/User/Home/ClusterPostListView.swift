import SwiftUI
import FirebaseCore
import FirebaseAuth

struct ClusterPostListView: View {
    let posts: [CampusPost]
    let postLookup: [UUID: Post]
    let postLookupByDocumentID: [String: Post]
    let onPostSelected: (CampusPost) -> Void
    let onLike: (CampusPost) -> Void
    let onDislike: (CampusPost) -> Void

    private var sortedPosts: [CampusPost] {
        posts.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 44, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            Text("Posts (\(posts.count))")
                .font(.title3.weight(.bold))
                .foregroundColor(Color.Brand.primary)
                .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedPosts) { post in
                        let resolvedFirebasePost = post.sourcePostID.flatMap { postLookupByDocumentID[$0] } ?? postLookup[post.id]
                        ClusterPostCard(
                            post: post,
                            firebasePost: resolvedFirebasePost,
                            onSelect: { onPostSelected(post) },
                            onLike: { onLike(post) },
                            onDislike: { onDislike(post) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

private struct ClusterPostCard: View {
    let post: CampusPost
    let firebasePost: Post?
    let onSelect: () -> Void
    let onLike: () -> Void
    let onDislike: () -> Void
    
    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var userReaction: String?
    @State private var localLikeCount: Int = 0
    @State private var localDislikeCount: Int = 0
    @State private var isReactionSubmitting = false

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(post.createdAt)
        let days = Int(interval / 86400)
        let hours = Int(interval / 3600)
        if days > 0 { return "Posted \(days)d ago" }
        if hours > 0 { return "Posted \(hours)h ago" }
        let minutes = max(1, Int(interval / 60))
        return "Posted \(minutes)m ago"
    }

    private var categoryColor: Color {
        switch post.category {
        case .casual: return .yellow
        case .lostFound: return .teal
        case .complaint: return .purple
        case .event: return .orange
        case .question: return .blue
        case .announcement: return .gray
        case .arChallenge: return .green
        }
    }

    private var firstPhotoURL: URL? {
        guard let photoPath = firebasePost?.photoPaths.first else { return nil }
        guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let escapedPath = photoPath.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(categoryColor)
                            .frame(width: 10, height: 10)

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

                    Text(post.author)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text(post.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let firstPhotoURL {
                    CachedRemoteImage(url: firstPhotoURL, cacheKey: firstPhotoURL.absoluteString) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.systemGray5))
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            HStack {
                Text(timeAgo)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.systemGray6))
                    )

                Spacer()

                HStack(spacing: 14) {
                    Button(action: handleLikeTap) {
                        HStack(spacing: 4) {
                            Image(systemName: userReaction == "like" ? "arrow.up.circle.fill" : "arrow.up")
                                .font(.caption.weight(.bold))
                                .foregroundColor(userReaction == "like" ? .purple : .primary)
                            Text("\(localLikeCount)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isReactionSubmitting)

                    Button(action: handleDislikeTap) {
                        HStack(spacing: 4) {
                            Image(systemName: userReaction == "dislike" ? "arrow.down.circle.fill" : "arrow.down")
                                .font(.caption.weight(.bold))
                                .foregroundColor(userReaction == "dislike" ? .orange : .primary)
                            Text("\(localDislikeCount)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isReactionSubmitting)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.Brand.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
        )
        .contentShape(Rectangle())
        .onAppear {
            localLikeCount = firebasePost?.likeCount ?? 0
            localDislikeCount = firebasePost?.dislikeCount ?? 0
            Task { await loadUserReaction() }
        }
        .onChange(of: firebasePost?.likeCount) { _, newValue in
            if let newValue { localLikeCount = newValue }
        }
        .onChange(of: firebasePost?.dislikeCount) { _, newValue in
            if let newValue { localDislikeCount = newValue }
        }
    }

    private func handleLikeTap() {
        guard !isReactionSubmitting else { return }
        isReactionSubmitting = true

        let previous = userReaction
        if previous == "like" {
            userReaction = nil
            localLikeCount = max(0, localLikeCount - 1)
        } else if previous == "dislike" {
            userReaction = "like"
            localDislikeCount = max(0, localDislikeCount - 1)
            localLikeCount += 1
        } else {
            userReaction = "like"
            localLikeCount += 1
        }

        onLike()
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run { isReactionSubmitting = false }
        }
    }

    private func handleDislikeTap() {
        guard !isReactionSubmitting else { return }
        isReactionSubmitting = true

        let previous = userReaction
        if previous == "dislike" {
            userReaction = nil
            localDislikeCount = max(0, localDislikeCount - 1)
        } else if previous == "like" {
            userReaction = "dislike"
            localLikeCount = max(0, localLikeCount - 1)
            localDislikeCount += 1
        } else {
            userReaction = "dislike"
            localDislikeCount += 1
        }

        onDislike()
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run { isReactionSubmitting = false }
        }
    }

    private func loadUserReaction() async {
        guard let postId = firebasePost?.id,
              let userId = authManager.user?.uid else { return }
        do {
            let reaction = try await postManager.getUserReaction(postId: postId, userId: userId)
            await MainActor.run { userReaction = reaction }
        } catch {
            // Non-fatal for UI responsiveness.
        }
    }
}
