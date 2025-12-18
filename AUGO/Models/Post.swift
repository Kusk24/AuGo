import Foundation
import CoreLocation
import FirebaseFirestore

struct Post: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let userId: String
    let content: String
    let category: Category
    let latitude: Double
    let longitude: Double
    let date: Date
    var likeCount: Int
    var dislikeCount: Int
    var reportCount: Int
    var status: Status

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum Category: String, Codable, CaseIterable, Identifiable {
        case casual = "Casual"
        case lostFound = "Lost & Found"
        case complaint = "Complaint"
        case event = "Event"
        case question = "Question"
        case announcement = "Announcement"
        case arChallenge = "AR Challenge"
        var id: String { rawValue }
    }

    enum Status: String, Codable {
        case active, hidden, removed
    }

    init(id: String? = nil, userId: String, content: String, category: Category, coordinate: CLLocationCoordinate2D, date: Date = Date(), likeCount: Int = 0, dislikeCount: Int = 0, reportCount: Int = 0, status: Status = .active) {
        self.id = id
        self.userId = userId
        self.content = content
        self.category = category
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.date = date
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
        self.reportCount = reportCount
        self.status = status
    }
}

// Supporting structure for Map Clusters
struct PostCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let posts: [Post]
    var count: Int { posts.count }
}
