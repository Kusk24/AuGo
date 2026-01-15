import SwiftUI

// --------------------------------------------
// MARK: - POST PIN (Unified size & flat color)
// --------------------------------------------
struct PostPinView: View {
    let post: CampusPost

    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 18))   // unified size
            .foregroundColor(colorFor(post.category))  // pure color
    }

    private func colorFor(_ category: PostCategory) -> Color {
        switch category {
        case .casual:
            return .teal                       // casual = teal
        case .lostFound:
            return .red                        // lost & found = red
        case .complaint:
            return Color(red: 1.0, green: 0.84, blue: 0.0) // dandelion
        }
    }
}

// --------------------------------------------
// MARK: - POST BUBBLE (Expanded on tap)
// --------------------------------------------
struct PostBubbleView: View {
    let post: CampusPost
    var onReport: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text(post.message)
                    .font(.caption)
                    .foregroundColor(.black)

                HStack {
                    Text(post.author)
                        .font(.caption2.bold())
                        .foregroundColor(.gray)

                    Spacer()

                    Text(relativeTime(from: post.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    // Report button
                    if let onReport = onReport {
                        Button(action: onReport) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
            )

            Triangle()
                .fill(.white)
                .frame(width: 12, height: 8)

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(colorFor(post.category))
        }
    }

    private func colorFor(_ category: PostCategory) -> Color {
        switch category {
        case .casual:
            return .teal
        case .lostFound:
            return .red
        case .complaint:
            return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }

    private func relativeTime(from date: Date) -> String {
        let mins = Int(-date.timeIntervalSinceNow / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins/60)h ago"
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

// --------------------------------------------
// MARK: - POST ANNOTATION WRAPPER
// --------------------------------------------
struct PostAnnotationView: View {
    let post: CampusPost
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if isSelected {
                PostBubbleView(post: post)
            } else {
                PostPinView(post: post)
            }
        }
        .buttonStyle(.plain)
    }
}

// --------------------------------------------
// MARK: - ANNOUNCEMENT PIN (unchanged style)
// --------------------------------------------
struct AnnouncementPinView: View {
    let announcement: Announcement
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(announcement.department)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white)
                    .clipShape(Capsule())

                Image(systemName: "megaphone.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.purple)
            }
        }
        .buttonStyle(.plain)
    }
}
