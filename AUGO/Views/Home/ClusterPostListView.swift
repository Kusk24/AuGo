import SwiftUI

struct ClusterPostListView: View {
    let posts: [Post]

    var body: some View {
        NavigationStack {
            List {
                ForEach(posts) { post in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.content)
                            .font(.body)

                        HStack {
                            Text(post.userId)
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(relativeTime(from: post.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Posts")
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
