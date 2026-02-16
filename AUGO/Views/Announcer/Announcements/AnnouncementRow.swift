import SwiftUI

struct AnnouncementRow: View {
    
    let announcement: Announcement
    var onEdit: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            HStack {
                Text(announcement.title)
                    .font(.headline)
                
                if announcement.isUrgent {
                    Text("URGENT")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                StatusBadge(status: announcement.displayStatus())
            }
            
            Text(announcement.body)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(.secondary)
            
            Text("Submitted: \(announcement.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)

            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit & Resubmit", systemImage: "square.and.pencil")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(Color.Brand.primary)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }
}
