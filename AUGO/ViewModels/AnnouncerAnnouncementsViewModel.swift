import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class AnnouncerAnnouncementsViewModel: ObservableObject {

    @Published var announcements: [Announcement] = []
    @Published var selectedFilter: AnnouncerAnnouncementFilter = .all
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening() {
        guard let email = Auth.auth().currentUser?.email?.lowercased() else {
            print("❌ No logged-in email")
            return
        }

        print("👤 CURRENT EMAIL:", email)
        isLoading = true

        listener = db.collection("announcements")
            .whereField("createdByEmail", isEqualTo: email)   // ✅ FIX
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error = error {
                    print("❌ Firestore error:", error)
                    return
                }

                self.announcements = snapshot?.documents
                    .compactMap(self.parseAnnouncement)
                    .sorted { $0.createdAt > $1.createdAt } ?? []
            }
    }

    var filteredAnnouncements: [Announcement] {
        guard let status = selectedFilter.status else {
            return announcements
        }
        return announcements.filter { $0.status == status }
    }

    // MARK: - Parsing (STRICT)
    private func parseAnnouncement(_ doc: QueryDocumentSnapshot) -> Announcement? {
        let data = doc.data()

        guard
            let title = data["title"] as? String,
            let body = data["body"] as? String,
            let department = data["department"] as? String,
            let isUrgent = data["isUrgent"] as? Bool,
            let createdByUID = data["createdByUID"] as? String,
            let createdByEmail = data["createdByEmail"] as? String,
            let createdByName = data["createdByName"] as? String,
            let statusRaw = data["status"] as? String,
            let status = AnnouncementStatus(rawValue: statusRaw),
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
            let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue(),
            let startDate = (data["startDate"] as? Timestamp)?.dateValue(),
            let endDate = (data["endDate"] as? Timestamp)?.dateValue()
        else {
            print("❌ Invalid announcement:", doc.documentID)
            return nil
        }

        let approvedAt = (data["approvedAt"] as? Timestamp)?.dateValue()
        let rejectedAt = (data["rejectedAt"] as? Timestamp)?.dateValue()
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let link = data["link"] as? String

        return Announcement(
            id: doc.documentID,
            title: title,
            body: body,
            department: department,
            isUrgent: isUrgent,
            link: link,
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
            isRead: nil
        )
    }
}
