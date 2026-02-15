import Foundation
import CoreLocation

enum AnnouncementStatus: String, Codable {
    case pending
    case approved
    case declined
    case rejected
    case active
    case expired
    case removed
}

struct Announcement: Identifiable, Codable {
    let id: String                  // Firestore document ID
    
    // MARK: - Content
    let title: String
    let body: String
    let department: String
    let isUrgent: Bool
    let link: String?               // ✅ NEW (optional)
    
    // MARK: - Ownership
    let createdByUID: String
    let createdByName: String
    let createdByEmail: String
    
    // MARK: - Lifecycle
    let status: AnnouncementStatus
    let createdAt: Date
    let submittedAt: Date
    let approvedAt: Date?
    let rejectedAt: Date?
    
    // MARK: - Scheduling
    let startDate: Date
    let endDate: Date
    
    // MARK: - Location
    let latitude: Double?
    let longitude: Double?
    
    // MARK: - Client-only
    var isRead: Bool?
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
