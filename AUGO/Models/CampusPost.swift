import Foundation
import CoreLocation

enum PostCategory: String, CaseIterable, Identifiable {
    case casual = "Casual"
    case lostFound = "Lost & Found"
    case complaint = "Complaint"
    case event = "Event"
    case question = "Question"
    case announcement = "Announcement"
    case arChallenge = "AR Challenge"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .casual: return "Casual"
        case .lostFound: return "Lost"
        case .complaint: return "Comp"
        case .event: return "Event"
        case .question: return "Q"
        case .announcement: return "Ann"
        case .arChallenge: return "AR"
        }
    }
}

struct CampusPost: Identifiable {
    let id = UUID()
    let author: String
    let message: String
    let coordinate: CLLocationCoordinate2D
    let category: PostCategory
    let createdAt: Date
}

// MARK: - Equatable (manual)
extension CampusPost: Equatable {
    static func == (lhs: CampusPost, rhs: CampusPost) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable (manual)
extension CampusPost: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
