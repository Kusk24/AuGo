import SwiftUI

struct ClusterPostListView: View {
    let posts: [CampusPost]
    let postLookup: [UUID: Post]
    let onPostSelected: (CampusPost) -> Void

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
                        Button {
                            onPostSelected(post)
                        } label: {
                            ClusterPostCard(
                                post: post,
                                firebasePost: postLookup[post.id]
                            )
                        }
                        .buttonStyle(.plain)
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
        case .event: return .orange
        case .question: return .blue
        case .announcement: return .purple
        case .arChallenge: return .green
        case .lostFound: return .red
        case .complaint: return .mint
        }
    }

    var body: some View {
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
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.purple)
                        Text("\(firebasePost?.likeCount ?? 0)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.black)
                        Text("\(firebasePost?.dislikeCount ?? 0)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
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
}
