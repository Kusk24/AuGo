// Report.swift
import Foundation
import FirebaseFirestore

struct Report: Codable, Identifiable {
    @DocumentID var id: String?
    let date: Date
    let postId: String
    let category: ReportCategory
    var reportCount: Int
    var status: ReportStatus
    
    enum ReportCategory: String, Codable {
        case spam
        case harassment
        case inappropriate
        case misinformation
        case other
    }
    
    enum ReportStatus: String, Codable {
        case pending
        case reviewed
        case resolved
        case dismissed
    }
    
    init(id: String? = nil, date: Date = Date(), postId: String, category: ReportCategory, reportCount: Int = 1, status: ReportStatus = .pending) {
        self.id = id
        self.date = date
        self.postId = postId
        self.category = category
        self.reportCount = reportCount
        self.status = status
    }
}
