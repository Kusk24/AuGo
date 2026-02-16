// Announcer.swift
import Foundation
import FirebaseFirestore

struct Announcer: Codable, Identifiable {
    @DocumentID var id: String?
    
    let name: String
    let email: String
    let phone: String
    
    let affiliationName: String
    let affiliationType: AffiliationType
    
    let role: String          // keep as String unless you control values
    let status: AnnouncerStatus
    
    let totalAnnouncements: Int
    let joinedDate: Date
    
    enum AffiliationType: String, Codable {
        case faculty
        case studentOrganization = "student_org"
        case other
    }
    
    enum AnnouncerStatus: String, Codable {
        case active
        case inactive
        case suspended
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case role
        case status
        case totalAnnouncements = "total_announcements"
        case joinedDate = "joined_date"
        case affiliationName = "affiliation_name"
        case affiliationType = "affiliation_type"
    }
}
