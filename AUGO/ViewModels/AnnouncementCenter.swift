import Foundation
import Combine
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class AnnouncementCenter: ObservableObject {
    
    @Published var announcements: [Announcement] = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init() {
        listenToActiveAnnouncements()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Unread count
    var unreadCount: Int {
        announcements.filter { !($0.isRead ?? false) }.count
    }
    
    // MARK: - Read state
    
    func markAllAsRead() {
        for index in announcements.indices {
            announcements[index].isRead = true
        }
    }
    
    func markAsRead(_ announcement: Announcement) {
        if let idx = announcements.firstIndex(where: { $0.id == announcement.id }) {
            announcements[idx].isRead = true
        }
    }
    
    // MARK: - Firestore listener (ACTIVE announcements only)
    
    private func listenToActiveAnnouncements() {
        listener = db.collection("announcements")
            .whereField("status", isEqualTo: "active")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                
                if let error = error {
                    print("❌ Firestore announcement error:", error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.announcements = []
                    return
                }
                
                let now = Date()
                self.announcements = documents.compactMap { doc in
                    self.parseAnnouncement(doc)
                }
                .filter { ann in
                    ann.startDate <= now && now <= ann.endDate
                }
                .sorted { $0.createdAt > $1.createdAt }
            }
    }
    
    // MARK: - Firestore → Model
    private func parseAnnouncement(_ doc: QueryDocumentSnapshot) -> Announcement? {
        let data = doc.data()
        
        guard
            let title = data["title"] as? String,
            let body = data["body"] as? String,
            let department = data["department"] as? String,
            let isUrgent = data["isUrgent"] as? Bool,
            let createdByUID = data["createdByUID"] as? String,
            let createdByName = data["createdByName"] as? String,
            let createdByEmail = data["createdByEmail"] as? String,
            let statusRaw = data["status"] as? String,
            let status = AnnouncementStatus.fromFirestore(statusRaw),
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
            let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue(),
            let startDate = (data["startDate"] as? Timestamp)?.dateValue(),
            let endDate = (data["endDate"] as? Timestamp)?.dateValue()
        else {
            print("⚠️ Invalid announcement document:", doc.documentID)
            return nil
        }
        
        let approvedAt = (data["approvedAt"] as? Timestamp)?.dateValue()
        let rejectedAt = (data["rejectedAt"] as? Timestamp)?.dateValue()
        
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let link = data["link"] as? String
        let photoPaths = data["photoPaths"] as? [String] ?? []
        let coinReward = (data["coinReward"] as? Double)
            ?? (data["coinReward"] as? NSNumber)?.doubleValue
            ?? 0.2
        
        return Announcement(
            id: doc.documentID,
            title: title,
            body: body,
            department: department,
            isUrgent: isUrgent,
            link: link,
            photoPaths: photoPaths,
            coinReward: coinReward,
            likeCount: data["likeCount"] as? Int ?? 0,
            dislikeCount: data["dislikeCount"] as? Int ?? 0,
            createdByUID: createdByUID,
            createdByName: createdByName,
            createdByEmail: createdByEmail,
            status: status,
            createdAt: createdAt,
            submittedAt: submittedAt,
            approvedAt: approvedAt,
            rejectedAt: rejectedAt,
            startDate: startDate,
            endDate: endDate,
            latitude: latitude,
            longitude: longitude,
            isRead: false
        )
    }
}
