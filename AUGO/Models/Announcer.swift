// Announcer.swift
import Foundation
import FirebaseFirestore

struct Announcer: Codable, Identifiable {
    @DocumentID var id: String?
    let name: String
    let email: String
    let faculty: String
    let organization: String
    let role: AnnouncerRole
    var status: AnnouncerStatus
    let createdAt: Date
    
    enum AnnouncerRole: String, Codable {
        case admin
        case facultyStaff
        case studentOrganization
        case moderator
    }
    
    enum AnnouncerStatus: String, Codable {
        case active
        case inactive
        case suspended
    }
    
    init(id: String? = nil, name: String, email: String, faculty: String, organization: String, role: AnnouncerRole, status: AnnouncerStatus = .active, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.faculty = faculty
        self.organization = organization
        self.role = role
        self.status = status
        self.createdAt = createdAt
    }
}
