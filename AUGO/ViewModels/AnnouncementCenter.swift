import Foundation
import Combine
import CoreLocation

final class AnnouncementCenter: ObservableObject {

    @Published var announcements: [Announcement] = []

    init() {
        seedMockAnnouncements()
    }

    /// Number of announcements not yet read
    var unreadCount: Int {
        announcements.filter { !$0.isRead }.count
    }

    // MARK: - Read state

    func markAllAsRead() {
        for index in announcements.indices {
            announcements[index].isRead = true
        }
    }

    func markAsRead(_ announcement: Announcement) {
        if let idx = announcements.firstIndex(where: { $0.id == announcement.id }) {
            announcements[idx].isRead = true
        }
    }

    // MARK: - Mock data

    private func seedMockAnnouncements() {
        let now = Date()
        let center = CLLocationCoordinate2D(latitude: 13.61194,
                                            longitude: 100.83700)

        announcements = [
            Announcement(
                title: "Online Pre-registration Period for 2/2025",
                department: "VMES",
                body: """
                Dear VMES students,

                • 60x – 65x students (All faculties) on Tuesday, October 21st, 2025 between 11:45 – 12:30.
                • 66x students (All faculties) on Tuesday, October 21st, 2025 between 14:45 – 15:30.

                If 60–66x students miss their recommended periods, you have another chance to pre-register on Tuesday, October 21st, 2025 between 15:30 – 16:30.

                • 67x students (All faculties) on Wednesday, October 22nd, 2025 between 10:30 – 11:15.
                • 68x students (All faculties) on Wednesday, October 22nd, 2025 between 13:30 – 14:15.

                Sincerely yours,
                Allapon Hutasin
                Assistant Dean for Academic Affairs
                Vincent Mary School of Engineering, Science and Technology
                """,
                date: now.addingTimeInterval(-60 * 60 * 2),   // 2h ago
                isUrgent: true,
                isRead: false,
                coordinate: offset(center, dLat: 0.0003, dLon: 0.0004)
            ),
            Announcement(
                title: "Library Quiet Zone Maintenance",
                department: "Library",
                body: """
                The Quiet Zone on the 3rd floor will be temporarily closed for maintenance
                on Friday, October 24th, 2025 from 09:00–12:00.

                Please use the group study rooms or 4th floor during this time.
                """,
                date: now.addingTimeInterval(-60 * 60 * 24),  // 1 day ago
                isUrgent: false,
                isRead: false,
                coordinate: offset(center, dLat: -0.0004, dLon: 0.0002)
            ),
            Announcement(
                title: "Career Fair 2025 Registration",
                department: "Career Center",
                body: """
                Registration for Career Fair 2025 is now open.

                Students are encouraged to register via AU Spark within this week.
                Formal attire is required on the event day.
                """,
                date: now.addingTimeInterval(-60 * 60 * 24 * 3),  // 3 days ago
                isUrgent: false,
                isRead: false,
                coordinate: offset(center, dLat: 0.0001, dLon: -0.0005)
            )
        ]

        // Latest first
        announcements.sort { $0.date > $1.date }
    }

    private func offset(_ coord: CLLocationCoordinate2D,
                        dLat: Double,
                        dLon: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coord.latitude + dLat,
            longitude: coord.longitude + dLon
        )
    }
}
