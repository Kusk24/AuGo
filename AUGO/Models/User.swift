// User.swift
import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    
    let studentID: String
    let name: String
    let nickname: String
    let email: String
    let faculty: String
    
    let birthDate: Date
    let joinedDate: Date
    let lastWarningDate: Date?
    
    var warningCount: Int
    var status: UserStatus
    var score: Int

    enum UserStatus: String, Codable {
        case active
        case suspended
        case banned
    }
}

