import Foundation
import Combine
import CoreLocation

@MainActor
final class AnnouncementCenter: ObservableObject {

    @Published private(set) var announcements: [Announcement] = []

    init() {
        seedMockAnnouncements()
    }

    // MARK: - Computed

    var unreadCount: Int {
        announcements.filter { !$0.isRead }.count
    }

    // MARK: - Read state

    func markAllAsRead() {
        announcements.indices.forEach {
            announcements[$0].isRead = true
        }
    }

    func markAsRead(_ announcement: Announcement) {
        guard let idx = announcements.firstIndex(where: { $0.id == announcement.id }) else { return }
        announcements[idx].isRead = true
    }

    // MARK: - Mock data

    private func seedMockAnnouncements() {
        let now = Date()
        let center = CLLocationCoordinate2D(
            latitude: 13.61194,
            longitude: 100.83700
        )

        announcements = [
            Announcement(
                title: "Online Pre-registration Period for 2/2025",
                department: "VMES",
                body: """
                Dear VMES students,

                • 60x – 65x students on Tuesday, October 21st, 2025 between 11:45 – 12:30.
                • 66x students on Tuesday, October 21st, 2025 between 14:45 – 15:30.
                """,
                date: now.addingTimeInterval(-7200),
                isUrgent: true,
                isRead: false,
                coordinate: offset(center, dLat: 0.0003, dLon: 0.0004)
            ),
            Announcement(
                title: "Library Quiet Zone Maintenance",
                department: "Library",
                body: "Quiet Zone closed on Friday 09:00–12:00.",
                date: now.addingTimeInterval(-86400),
                isUrgent: false,
                isRead: false,
                coordinate: offset(center, dLat: -0.0004, dLon: 0.0002)
            )
        ]

        announcements.sort { $0.date > $1.date }
    }

    private func offset(
        _ coord: CLLocationCoordinate2D,
        dLat: Double,
        dLon: Double
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coord.latitude + dLat,
            longitude: coord.longitude + dLon
        )
    }
}
