// Post.swift
import Foundation
import FirebaseFirestore
import CoreLocation

struct Post: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String
    let date: Date
    let content: String
    let category: PostCategory
    let latitude: Double
    let longitude: Double
    var likeCount: Int
    var dislikeCount: Int
    var reportCount: Int
    var status: PostStatus
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    enum PostCategory: String, Codable, CaseIterable, Identifiable {
        case casual = "Casual"
        case event = "Event"
        case question = "Question"
        case announcement = "Announcement"
        case arChallenge = "AR Challenge"
        
        var id: String { rawValue }
    }
    
    enum PostStatus: String, Codable {
        case active
        case hidden
        case removed
    }
    
    init(id: String? = nil, userId: String, date: Date = Date(), content: String, category: PostCategory, latitude: Double = 0, longitude: Double = 0, likeCount: Int = 0, dislikeCount: Int = 0, reportCount: Int = 0, status: PostStatus = .active) {
        self.id = id
        self.userId = userId
        self.date = date
        self.content = content
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
        self.reportCount = reportCount
        self.status = status
    }
}
