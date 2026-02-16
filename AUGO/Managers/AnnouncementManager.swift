import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

@MainActor
final class AnnouncementManager: ObservableObject {
    struct AnnouncementReactionResult {
        let reaction: String?
        let likeCount: Int
        let dislikeCount: Int
        let coinAwarded: Double
    }
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    func createAnnouncement(
        title: String,
        body: String,
        department: String,
        isUrgent: Bool,
        link: String?,
        coinReward: Double,
        startDate: Date,
        endDate: Date,
        coordinate: CLLocationCoordinate2D,
        announcerName: String,
        photoDatas: [Data] = []
    ) async throws {
        
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            throw NSError(
                domain: "AUTH",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Missing authenticated email"]
            )
        }
        
        isLoading = true
        defer { isLoading = false }

        let announcementRef = db.collection("announcements").document()
        let photoPaths = try await uploadAnnouncementPhotos(
            announcementId: announcementRef.documentID,
            userId: user.uid,
            photoDatas: photoDatas
        )
        
        let data: [String: Any] = [
            "title": title,
            "body": body,
            "department": department,
            "isUrgent": isUrgent,
            "link": link as Any,
            "coinReward": max(0, coinReward),
            
            "createdByUID": user.uid,
            "createdByEmail": email,        // ✅ REQUIRED
            "createdByName": announcerName,
            
            "status": "pending",
            "createdAt": Timestamp(date: Date()),
            "submittedAt": Timestamp(date: Date()),
            "approvedAt": NSNull(),
            "rejectedAt": NSNull(),
            "photoPaths": photoPaths,
            "likeCount": 0,
            "dislikeCount": 0,
            
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ]
        
        try await announcementRef.setData(data)
    }

    func updateAndResubmitAnnouncement(
        announcementID: String,
        title: String,
        body: String,
        department: String,
        isUrgent: Bool,
        link: String?,
        coinReward: Double,
        startDate: Date,
        endDate: Date,
        coordinate: CLLocationCoordinate2D,
        photoDatas: [Data]? = nil
    ) async throws {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            throw NSError(
                domain: "AUTH",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Missing authenticated email"]
            )
        }

        isLoading = true
        defer { isLoading = false }

        var updatePayload: [String: Any] = [
            "title": title,
            "body": body,
            "department": department,
            "isUrgent": isUrgent,
            "link": link as Any,
            "coinReward": max(0, coinReward),
            "createdByUID": user.uid,
            "createdByEmail": email,
            "status": AnnouncementStatus.pending.rawValue,
            "submittedAt": Timestamp(date: Date()),
            "approvedAt": NSNull(),
            "rejectedAt": NSNull(),
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ]

        if let photoDatas {
            let uploaded = try await uploadAnnouncementPhotos(
                announcementId: announcementID,
                userId: user.uid,
                photoDatas: photoDatas
            )
            updatePayload["photoPaths"] = uploaded
        }

        try await db.collection("announcements").document(announcementID).updateData(updatePayload)
    }

    func getUserAnnouncementReaction(announcementId: String, userId: String) async throws -> String? {
        let reactionId = "\(userId)_\(announcementId)"
        let doc = try await db.collection("announcement_reactions").document(reactionId).getDocument()
        guard doc.exists else { return nil }
        return doc.data()?["reaction"] as? String
    }

    func reactToAnnouncement(
        announcementId: String,
        userId: String,
        reaction: String,
        awardCoin: Bool = true
    ) async throws -> AnnouncementReactionResult {
        precondition(reaction == "like" || reaction == "dislike")

        let announcementRef = db.collection("announcements").document(announcementId)
        let userRef = db.collection("users").document(userId)
        let reactionRef = db.collection("announcement_reactions").document("\(userId)_\(announcementId)")
        let now = Date()

        let result = try await db.runTransaction { transaction, errorPointer in
            let announcementSnap: DocumentSnapshot
            let reactionSnap: DocumentSnapshot
            var userSnap: DocumentSnapshot?
            do {
                announcementSnap = try transaction.getDocument(announcementRef)
                reactionSnap = try transaction.getDocument(reactionRef)
                if awardCoin {
                    userSnap = try transaction.getDocument(userRef)
                }
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard announcementSnap.exists else {
                errorPointer?.pointee = NSError(
                    domain: "AnnouncementReaction",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Announcement not found."]
                )
                return nil
            }

            var likeCount = announcementSnap.data()?["likeCount"] as? Int ?? 0
            var dislikeCount = announcementSnap.data()?["dislikeCount"] as? Int ?? 0
            let existingReaction = reactionSnap.data()?["reaction"] as? String
            var newReaction: String? = existingReaction

            if existingReaction == reaction {
                newReaction = nil
                if reaction == "like" {
                    likeCount = max(0, likeCount - 1)
                    transaction.updateData(["likeCount": FieldValue.increment(Int64(-1))], forDocument: announcementRef)
                } else {
                    dislikeCount = max(0, dislikeCount - 1)
                    transaction.updateData(["dislikeCount": FieldValue.increment(Int64(-1))], forDocument: announcementRef)
                }
                transaction.deleteDocument(reactionRef)
            } else if let existingReaction {
                newReaction = reaction
                if existingReaction == "like" {
                    likeCount = max(0, likeCount - 1)
                    dislikeCount += 1
                    transaction.updateData([
                        "likeCount": FieldValue.increment(Int64(-1)),
                        "dislikeCount": FieldValue.increment(Int64(1))
                    ], forDocument: announcementRef)
                } else {
                    dislikeCount = max(0, dislikeCount - 1)
                    likeCount += 1
                    transaction.updateData([
                        "dislikeCount": FieldValue.increment(Int64(-1)),
                        "likeCount": FieldValue.increment(Int64(1))
                    ], forDocument: announcementRef)
                }
                transaction.updateData([
                    "reaction": reaction,
                    "timestamp": Timestamp(date: now)
                ], forDocument: reactionRef)
            } else {
                newReaction = reaction
                if reaction == "like" {
                    likeCount += 1
                    transaction.updateData(["likeCount": FieldValue.increment(Int64(1))], forDocument: announcementRef)
                } else {
                    dislikeCount += 1
                    transaction.updateData(["dislikeCount": FieldValue.increment(Int64(1))], forDocument: announcementRef)
                }
                transaction.setData([
                    "userId": userId,
                    "announcementId": announcementId,
                    "reaction": reaction,
                    "timestamp": Timestamp(date: now)
                ], forDocument: reactionRef)
            }

            var coinAwarded = 0.0
            if awardCoin, let userSnap {
                let userData = userSnap.data() ?? [:]
                var rewardMap = userData["announcementReactionRewards"] as? [String: Bool] ?? [:]
                let hasRewarded = rewardMap[announcementId] ?? false
                if !hasRewarded, newReaction != nil {
                    let rewardFromAnnouncement = (announcementSnap.data()?["coinReward"] as? Double)
                        ?? (announcementSnap.data()?["coinReward"] as? NSNumber)?.doubleValue
                        ?? 0.2
                    coinAwarded = max(0, rewardFromAnnouncement)
                    rewardMap[announcementId] = true
                    let currentBalance = (userData["coinBalance"] as? Double) ?? 0
                    transaction.setData([
                        "coinBalance": currentBalance + coinAwarded,
                        "announcementReactionRewards": rewardMap
                    ], forDocument: userRef, merge: true)
                }
            }

            return [
                "reaction": newReaction as Any,
                "likeCount": likeCount,
                "dislikeCount": dislikeCount,
                "coinAwarded": coinAwarded
            ]
        }

        guard
            let map = result as? [String: Any],
            let likeCount = map["likeCount"] as? Int,
            let dislikeCount = map["dislikeCount"] as? Int,
            let coinAwarded = map["coinAwarded"] as? Double
        else {
            throw NSError(
                domain: "AnnouncementReaction",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to process announcement reaction."]
            )
        }

        return AnnouncementReactionResult(
            reaction: map["reaction"] as? String,
            likeCount: likeCount,
            dislikeCount: dislikeCount,
            coinAwarded: coinAwarded
        )
    }

    private func uploadAnnouncementPhotos(
        announcementId: String,
        userId: String,
        photoDatas: [Data]
    ) async throws -> [String] {
        let limitedPhotoDatas = Array(photoDatas.prefix(2))
        guard !limitedPhotoDatas.isEmpty else { return [] }

#if canImport(FirebaseStorage)
        let baseRef = Storage.storage().reference().child("announcement_photos").child(announcementId)
        var uploadedPaths: [String] = []

        for (index, data) in limitedPhotoDatas.enumerated() {
            guard !data.isEmpty else { continue }
            let fileRef = baseRef.child("\(userId)_\(Int(Date().timeIntervalSince1970))_\(index).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await fileRef.putDataAsync(data, metadata: metadata)
            uploadedPaths.append(fileRef.fullPath)
        }
        return uploadedPaths
#else
        _ = announcementId
        _ = userId
        _ = limitedPhotoDatas
        return []
#endif
    }
}
