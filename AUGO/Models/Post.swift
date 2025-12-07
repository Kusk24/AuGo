// Post.swift
import Foundation
import FirebaseFirestore

struct Post: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String
    let date: Date
    let content: String
    let category: PostCategory
    var likeCount: Int
    var dislikeCount: Int
    var reportCount: Int
    var status: PostStatus
    
    enum PostCategory: String, Codable {
        case general
        case event
        case question
        case announcement
        case arChallenge
    }
    
    enum PostStatus: String, Codable {
        case active
        case hidden
        case removed
    }
    
    init(id: String? = nil, userId: String, date: Date = Date(), content: String, category: PostCategory, likeCount: Int = 0, dislikeCount: Int = 0, reportCount: Int = 0, status: PostStatus = .active) {
        self.id = id
        self.userId = userId
        self.date = date
        self.content = content
        self.category = category
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
        self.reportCount = reportCount
        self.status = status
    }
}
