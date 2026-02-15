import SwiftUI

// --------------------------------------------
// MARK: - POST PIN (Unified size & flat color)
// --------------------------------------------
struct PostPinView: View {
    let post: CampusPost

    var body: some View {
        let visual = ContentSymbolKit.postVisual(for: post.category)
        return Image(systemName: visual.symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(visual.color)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }
}

// --------------------------------------------
// MARK: - POST BUBBLE (Expanded on tap)
// --------------------------------------------
struct PostBubbleView: View {
    let post: CampusPost
    var onReport: (() -> Void)? = nil

    var body: some View {
        let visual = ContentSymbolKit.postVisual(for: post.category)
        VStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                // Category badge
                HStack {
                    Label(post.category.rawValue, systemImage: visual.symbol)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(visual.color.opacity(0.2))
                        .foregroundColor(visual.color)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Report button
                    if let onReport = onReport {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.7))
                            .padding(8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onReport()
                            }
                    }
                }
                
                // Message content
                Text(post.message)
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)

                // Author and time info
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption2)
                        .foregroundColor(visual.color)
                    
                    Text("Posted by \(post.author)")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(relativeTime(from: post.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
            .frame(minWidth: 200, maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            )

            Triangle()
                .fill(.white)
                .frame(width: 12, height: 8)

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 23))
                .foregroundColor(visual.color)
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
    var onReport: (() -> Void)? = nil

    var body: some View {
        Group {
            if isSelected {
                PostBubbleView(post: post, onReport: onReport)
            } else {
                PostPinView(post: post)
            }
        }
        .onTapGesture {
            onTap()
        }
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
            VStack(spacing: 4) {
                Image(systemName: symbolName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(pinColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)

                Text(announcement.department)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private var pinColor: Color {
        switch announcement.status {
        case .pending:
            return .orange
        case .approved:
            return .blue
        case .active:
            return announcement.isUrgent ? .red : .green
        case .expired:
            return .gray
        case .removed:
            return .pink
        case .declined, .rejected:
            return .red
        }
    }

    private var symbolName: String {
        switch announcement.status {
        case .pending:
            return "clock.badge.exclamationmark.fill"
        case .approved:
            return "checkmark.seal.fill"
        case .active:
            return "megaphone.fill"
        case .expired:
            return "clock.fill"
        case .removed:
            return "slash.circle.fill"
        case .declined, .rejected:
            return "xmark.octagon.fill"
        }
    }
}
