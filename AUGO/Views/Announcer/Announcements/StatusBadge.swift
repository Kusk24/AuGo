import SwiftUI

struct StatusBadge: View {
    
    let status: AnnouncementStatus
    
    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
    
    private var color: Color {
        switch status {
        case .pending: return .gray
        case .scheduled: return .blue
        case .active: return .green
        case .declined: return .red
        case .expired: return .gray
        case .removed: return .pink
        @unknown default: return .gray
        }
    }
}
