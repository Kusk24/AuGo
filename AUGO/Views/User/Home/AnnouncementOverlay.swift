import SwiftUI

struct AnnouncementOverlay: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var announcementCenter: AnnouncementCenter

    @State private var showUrgentOnly = false

    private var filteredAnnouncements: [Announcement] {
        let source = announcementCenter.announcements
        if showUrgentOnly {
            return source.filter { $0.isUrgent }
        }
        return source
    }

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowing = false
                }

            // Card
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Announcements")
                            .font(.headline)

                        Text(headerSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        isShowing = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color(UIColor.systemGray5))
                            .clipShape(Circle())
                    }
                }
                .padding([.top, .horizontal])

                // Filter
                Picker("", selection: $showUrgentOnly) {
                    Text("All").tag(false)
                    Text("Urgent").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)

                Divider()

                // List of announcements
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredAnnouncements) { announcement in
                            AnnouncementCard(announcement: announcement)
                        }

                        if filteredAnnouncements.isEmpty {
                            Text("No announcements in this filter.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 80)
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut, value: isShowing)
    }

    private var headerSubtitle: String {
        let total = announcementCenter.announcements.count
        let urgent = announcementCenter.announcements.filter { $0.isUrgent }.count

        if showUrgentOnly {
            return "\(urgent) urgent announcement\(urgent == 1 ? "" : "s")"
        } else {
            return "\(total) announcement\(total == 1 ? "" : "s"), \(urgent) urgent"
        }
    }
}

// MARK: - Card for each announcement

private struct AnnouncementCard: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(announcement.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                if announcement.isUrgent {
                    Text("URGENT")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                }

                Spacer()
            }

            HStack(spacing: 6) {
                Text(announcement.department)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")

                Text(dateString(announcement.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(announcement.body)
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.systemGray6))
        )
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
