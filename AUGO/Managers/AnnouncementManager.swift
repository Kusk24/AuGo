import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine

@MainActor
final class AnnouncementManager: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func createAnnouncement(
        title: String,
        body: String,
        department: String,
        isUrgent: Bool,
        link: String?,
        startDate: Date,
        endDate: Date,
        coordinate: CLLocationCoordinate2D,
        announcerName: String
    ) async throws {

        guard let user = Auth.auth().currentUser,
              let email = user.email?.lowercased() else {
            throw NSError(
                domain: "AUTH",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Missing authenticated email"]
            )
        }

        isLoading = true
        defer { isLoading = false }

        let data: [String: Any] = [
            "title": title,
            "body": body,
            "department": department,
            "isUrgent": isUrgent,
            "link": link as Any,

            "createdByUID": user.uid,
            "createdByEmail": email,        // ✅ REQUIRED
            "createdByName": announcerName,

            "status": "pending",
            "createdAt": Timestamp(date: Date()),
            "submittedAt": Timestamp(date: Date()),
            "approvedAt": NSNull(),
            "rejectedAt": NSNull(),

            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),

            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ]

        try await db.collection("announcements").addDocument(data: data)
    }
}
