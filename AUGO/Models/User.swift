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
    var coinBalance: Int = 0
    var dailyPostCount: Int = 0
    var dailyPostCountDate: Date? = nil
    var lastCoinGrantDate: Date? = nil
    
    enum UserStatus: String, Codable {
        case active
        case suspended
        case banned
    }
}
