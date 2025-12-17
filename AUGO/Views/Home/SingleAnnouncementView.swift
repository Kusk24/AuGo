import SwiftUI

struct SingleAnnouncementView: View {
    let announcement: Announcement

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    Text(announcement.title)
                        .font(.title3.bold())

                    Text("Department: \(announcement.department)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(announcement.body)
                        .font(.body)
                        .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("Announcement")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
