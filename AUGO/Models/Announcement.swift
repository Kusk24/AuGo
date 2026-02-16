import Foundation
import CoreLocation

enum AnnouncementStatus: String, Codable {
    case pending
    case scheduled
    case declined
    case active
    case expired
    case removed

    static func fromFirestore(_ rawValue: String) -> AnnouncementStatus? {
        switch rawValue.lowercased() {
        case "pending":
            return .pending
        case "scheduled", "approved":
            return .scheduled
        case "declined", "rejected":
            return .declined
        case "active":
            return .active
        case "expired":
            return .expired
        case "removed":
            return .removed
        default:
            return nil
        }
    }
}

struct Announcement: Identifiable, Codable {
    let id: String                  // Firestore document ID
    
    // MARK: - Content
    let title: String
    let body: String
    let department: String
    let isUrgent: Bool
    let link: String?               // ✅ NEW (optional)
    let photoPaths: [String]
    let coinReward: Double
    let likeCount: Int
    let dislikeCount: Int
    
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

    func displayStatus(referenceDate now: Date = Date()) -> AnnouncementStatus {
        switch status {
        case .active where now < startDate:
            return .scheduled
        case .active where now > endDate:
            return .expired
        default:
            return status
        }
    }
}
