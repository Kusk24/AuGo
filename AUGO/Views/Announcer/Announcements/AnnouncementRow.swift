import SwiftUI

struct AnnouncementRow: View {
    
    let announcement: Announcement
    
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
                
                StatusBadge(status: announcement.status)
            }
            
            Text(announcement.body)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(.secondary)
            
            Text("Submitted: \(announcement.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}
