// User.swift
import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    var id: String?
    let studentID: String
    let name: String
    let nickname: String
    let email: String
    let faculty: String
    let birthDate: Date
    var warningCount: Int
    var status: UserStatus
    let joinedDate: Date
    
    enum UserStatus: String, Codable {
        case active
        case suspended
        case banned
    }
    
    init(id: String? = nil, studentID: String, name: String, nickname: String, email: String, faculty: String, birthDate: Date, warningCount: Int = 0, status: UserStatus = .active, joinedDate: Date = Date()) {
        self.id = id
        self.studentID = studentID
        self.name = name
        self.nickname = nickname
        self.email = email
        self.faculty = faculty
        self.birthDate = birthDate
        self.warningCount = warningCount
        self.status = status
        self.joinedDate = joinedDate
    }
}
