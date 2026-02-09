import SwiftUI

struct ClusterPostListView: View {
    let posts: [CampusPost]
    let onPostSelected: (CampusPost) -> Void
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(posts) { post in
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onPostSelected(post)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.message)
                                .font(.body)
                                .foregroundColor(.primary)

                            HStack {
                                Text(post.author)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(relativeTime(from: post.createdAt))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Posts (\(posts.count))")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func relativeTime(from date: Date) -> String {
        let mins = Int(-date.timeIntervalSinceNow / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }
}
