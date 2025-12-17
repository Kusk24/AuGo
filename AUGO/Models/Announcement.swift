import Foundation
import CoreLocation

struct Announcement: Identifiable {
    let id = UUID()
    let title: String
    let department: String
    let body: String
    let date: Date

    var isUrgent: Bool
    var isRead: Bool

    /// Optional location for map pin
    var coordinate: CLLocationCoordinate2D?
}
