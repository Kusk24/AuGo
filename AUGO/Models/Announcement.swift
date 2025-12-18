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
// Announcement.swift
//import Foundation
//import FirebaseFirestore
//
//struct Announcement: Codable, Identifiable {
//    @DocumentID var id: String?
//    let date: Date
//    let contentTopic: String
//    let content: String
//    var viewCount: Int
//    var status: AnnouncementStatus
//    let announcerId: String
//    
//    enum AnnouncementStatus: String, Codable {
//        case draft
//        case published
//        case archived
//    }
//    
//    init(id: String? = nil, date: Date = Date(), contentTopic: String, content: String, viewCount: Int = 0, status: AnnouncementStatus = .draft, announcerId: String) {
//        self.id = id
//        self.date = date
//        self.contentTopic = contentTopic
//        self.content = content
//        self.viewCount = viewCount
//        self.status = status
//        self.announcerId = announcerId
//    }
}
