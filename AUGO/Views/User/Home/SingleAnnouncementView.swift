import SwiftUI
import FirebaseFirestore
import FirebaseCore
import UIKit
import CoreLocation
import FirebaseAuth

struct SingleAnnouncementView: View {
    let announcement: Announcement
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var announcementManager = AnnouncementManager()
    @State private var liveAnnouncement: Announcement?
    @State private var isLoading = true
    @State private var listener: ListenerRegistration?
    @State private var userReaction: String?
    @State private var localLikeCount: Int
    @State private var localDislikeCount: Int
    @State private var reactionMessage: String?

    init(announcement: Announcement) {
        self.announcement = announcement
        _localLikeCount = State(initialValue: announcement.likeCount)
        _localDislikeCount = State(initialValue: announcement.dislikeCount)
    }

    private var displayAnnouncement: Announcement {
        liveAnnouncement ?? announcement
    }

    private var canReact: Bool {
        authManager.user?.uid != nil
    }

    private var canReactForCoins: Bool {
        authManager.role == .user
    }

    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading && liveAnnouncement == nil {
                    ProgressView("Loading announcement...")
                        .padding(.top, 40)
                }

                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        statusChip
                        if displayAnnouncement.isUrgent {
                            Label("Urgent", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundColor(.red)
                                .background(Color.red.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }

                    Text(displayAnnouncement.title)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    if !displayAnnouncement.photoPaths.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Photos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(displayAnnouncement.photoPaths, id: \.self) { path in
                                        if let url = storageDownloadURL(for: path) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .empty:
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemGray5))
                                                        ProgressView()
                                                    }
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                case .failure:
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemGray5))
                                                        Image(systemName: "photo").foregroundColor(.secondary)
                                                    }
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                            .frame(width: 220, height: 220)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Announcement")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(displayAnnouncement.body)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        detailRow("Department", value: displayAnnouncement.department, icon: "building.2.fill")
                        detailRow("By", value: displayAnnouncement.createdByName, icon: "person.circle.fill")
                        detailRow(
                            "Schedule",
                            value: "\(displayAnnouncement.startDate.formatted(date: .abbreviated, time: .shortened)) - \(displayAnnouncement.endDate.formatted(date: .abbreviated, time: .shortened))",
                            icon: "calendar"
                        )
                        detailRow(
                            "Reaction Reward",
                            value: "+\(String(format: "%.1f", displayAnnouncement.coinReward)) coins",
                            icon: "bitcoinsign.circle.fill"
                        )

                        if let coord = displayAnnouncement.coordinate {
                            Button {
                                openInMaps(coord)
                            } label: {
                                HStack {
                                    Image(systemName: "map.fill")
                                    Text("Open in Maps")
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.square")
                                }
                                .font(.body)
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    Divider()

                    HStack(spacing: 14) {
                        Label("\(localLikeCount)", systemImage: "hand.thumbsup.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.green)
                        Label("\(localDislikeCount)", systemImage: "hand.thumbsdown.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.orange)
                    }

                    if canReact {
                        HStack(spacing: 12) {
                            Button {
                                Task { await applyReaction("like") }
                            } label: {
                                HStack {
                                    Image(systemName: userReaction == "like" ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    Text("Like")
                                    Text("(\(localLikeCount))").font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(userReaction == "like" ? Color.green : Color.green.opacity(0.1))
                                .foregroundColor(userReaction == "like" ? .white : .green)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                Task { await applyReaction("dislike") }
                            } label: {
                                HStack {
                                    Image(systemName: userReaction == "dislike" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                    Text("Dislike")
                                    Text("(\(localDislikeCount))").font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(userReaction == "dislike" ? Color.orange : Color.orange.opacity(0.1))
                                .foregroundColor(userReaction == "dislike" ? .white : .orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if let reactionMessage {
                            Text(reactionMessage)
                                .font(.caption)
                                .foregroundColor(Color.Brand.coin)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                startListener()
                if canReact {
                    Task { await loadUserReaction() }
                }
            }
            .onDisappear {
                listener?.remove()
                listener = nil
            }
        }
    }

    private var statusChip: some View {
        let status = displayAnnouncement.displayStatus()
        let color: Color = {
            switch status {
            case .pending: return .gray
            case .scheduled: return .blue
            case .active: return .green
            case .declined: return .red
            case .expired: return .gray
            case .removed: return .pink
            }
        }()

        return Text(status.rawValue.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(color)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func detailRow(_ title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Color.Brand.primary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
            Spacer()
        }
    }

    private func startListener() {
        listener?.remove()
        isLoading = true

        listener = Firestore.firestore()
            .collection("announcements")
            .document(announcement.id)
            .addSnapshotListener { snapshot, _ in
                defer { isLoading = false }
                guard let snapshot, snapshot.exists, let data = snapshot.data() else { return }
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
                else { return }

                liveAnnouncement = Announcement(
                    id: snapshot.documentID,
                    title: title,
                    body: body,
                    department: department,
                    isUrgent: isUrgent,
                    link: data["link"] as? String,
                    photoPaths: data["photoPaths"] as? [String] ?? [],
                    coinReward: (data["coinReward"] as? Double)
                        ?? (data["coinReward"] as? NSNumber)?.doubleValue
                        ?? 0.2,
                    likeCount: data["likeCount"] as? Int ?? 0,
                    dislikeCount: data["dislikeCount"] as? Int ?? 0,
                    createdByUID: createdByUID,
                    createdByName: createdByName,
                    createdByEmail: createdByEmail,
                    status: status,
                    createdAt: createdAt,
                    submittedAt: submittedAt,
                    approvedAt: (data["approvedAt"] as? Timestamp)?.dateValue(),
                    rejectedAt: (data["rejectedAt"] as? Timestamp)?.dateValue(),
                    startDate: startDate,
                    endDate: endDate,
                    latitude: data["latitude"] as? Double,
                    longitude: data["longitude"] as? Double,
                    isRead: nil
                )
                localLikeCount = liveAnnouncement?.likeCount ?? localLikeCount
                localDislikeCount = liveAnnouncement?.dislikeCount ?? localDislikeCount
            }
    }

    private func loadUserReaction() async {
        guard let uid = authManager.user?.uid else { return }
        do {
            let reaction = try await announcementManager.getUserAnnouncementReaction(
                announcementId: announcement.id,
                userId: uid
            )
            await MainActor.run { userReaction = reaction }
        } catch {
            // Non-fatal. UI still works without prior reaction state.
        }
    }

    @MainActor
    private func applyReaction(_ reaction: String) async {
        guard let uid = authManager.user?.uid else { return }
        do {
            let result = try await announcementManager.reactToAnnouncement(
                announcementId: announcement.id,
                userId: uid,
                reaction: reaction,
                awardCoin: canReactForCoins
            )
            userReaction = result.reaction
            localLikeCount = result.likeCount
            localDislikeCount = result.dislikeCount
            if result.coinAwarded > 0 {
                reactionMessage = String(format: "Thanks for engaging. You earned +%.1f coin.", result.coinAwarded)
            } else {
                reactionMessage = nil
            }
        } catch {
            reactionMessage = "Reaction failed: \(error.localizedDescription)"
        }
    }

    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        let query = displayAnnouncement.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Announcement"
        guard let mapsURL = URL(string: "http://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=\(query)") else {
            return
        }
        UIApplication.shared.open(mapsURL)
    }

    private func storageDownloadURL(for assetPath: String) -> URL? {
        guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let escapedPath = assetPath.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
    }
}
