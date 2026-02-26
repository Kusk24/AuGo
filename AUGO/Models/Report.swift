// Report.swift
import Foundation
import FirebaseFirestore

struct Report: Codable, Identifiable {
    var id: String?
    let category: ReportCategory
    let description: String
    let postContent: String
    let postId: String
    var reportCount: Int
    let reportDate: Date
    let reported: ReportedUser // User who created the post
    let reporter: ReporterUser // User who reported the post
    var status: ReportStatus
    let updatedAt: Date
    
    struct ReportedUser: Codable {
        let id: String
        let name: String
    }
    
    struct ReporterUser: Codable {
        let id: String
        let name: String
    }
    
    enum ReportCategory: String, Codable {
        case spam
        case harassment
        case inappropriate
        case misinformation
        case scam
        case threat
        case impersonation
        case hates
        case other
    }
    
    enum ReportStatus: String, Codable {
        case pending
        case reviewed
        case resolved
        case dismissed
    }
    
    init(id: String? = nil, category: ReportCategory, description: String, postContent: String, postId: String, reportCount: Int = 1, reportDate: Date = Date(), reported: ReportedUser, reporter: ReporterUser, status: ReportStatus = .pending, updatedAt: Date = Date()) {
        self.id = id
        self.category = category
        self.description = description
        self.postContent = postContent
        self.postId = postId
        self.reportCount = reportCount
        self.reportDate = reportDate
        self.reported = reported
        self.reporter = reporter
        self.status = status
        self.updatedAt = updatedAt
    }
}
