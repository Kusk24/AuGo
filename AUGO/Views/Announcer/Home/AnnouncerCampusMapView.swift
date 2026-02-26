import SwiftUI
internal import MapKit
import FirebaseFirestore

struct AnnouncerCampusMapView: View {
    @Binding var showAnnouncement: Bool
    
    @EnvironmentObject var announcementCenter: AnnouncementCenter
    @EnvironmentObject var campusMapViewModel: CampusMapViewModel
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedAnnouncement: Announcement?
    @State private var isPresentingCreateAnnouncement = false
    @State private var showNotificationList = false
    @State private var mapAnnouncements: [Announcement] = []
    @State private var announcementsListener: ListenerRegistration?

    private var defaultMapRegion: MKCoordinateRegion {
        let span = campusMapViewModel.campusRegion.span
        let shiftedCenter = CLLocationCoordinate2D(
            latitude: campusMapViewModel.campusRegion.center.latitude,
            longitude: campusMapViewModel.campusRegion.center.longitude + (span.longitudeDelta * 0.075)
        )
        return MKCoordinateRegion(center: shiftedCenter, span: span)
    }
    
    var body: some View {
        ZStack {
            Color.Brand.appBackground
                .ignoresSafeArea()
            
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemGray6))
                .shadow(radius: 6)
                .overlay(
                    Map(position: $cameraPosition) {
                        
                        // User location
                        UserAnnotation()
                        
                        // Show only pending/active/scheduled/declined on announcer map.
                        ForEach(mapAnnouncements) { ann in
                            if let coord = ann.coordinate {
                                Annotation("", coordinate: coord) {
                                    AnnouncementPinView(announcement: ann) {
                                        announcementCenter.markAsRead(ann)
                                        selectedAnnouncement = ann
                                    }
                                }
                            }
                        }
                    }
                    .mapControls {
                        MapCompass()
                        MapPitchToggle()
                        MapUserLocationButton()
                    }
                )
                .padding()
            
            // ➕ CREATE ANNOUNCEMENT BUTTON
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        isPresentingCreateAnnouncement = true
                    } label: {
                        Circle()
                            .fill(Color.Brand.primary)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                    .font(.title3.bold())
                            )
                            .shadow(radius: 6)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            cameraPosition = .region(defaultMapRegion)
            startAnnouncementsListener()
        }
        .onDisappear {
            announcementsListener?.remove()
            announcementsListener = nil
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNotificationList = true
                } label: {
                    let hasUnread = notificationManager.unreadCount > 0
                    Image(systemName:
                        hasUnread
                        ? "bell.badge.fill"
                        : "bell.fill"
                    )
                    .symbolRenderingMode(hasUnread ? .palette : .monochrome)
                    .foregroundStyle(
                        hasUnread ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.Brand.primary),
                        Color.Brand.primary
                    )
                }
            }
        }
        .sheet(isPresented: $showNotificationList) {
            NotificationListView()
                .environmentObject(notificationManager)
        }
        .sheet(item: $selectedAnnouncement) { ann in
            SingleAnnouncementView(announcement: ann)
        }
        .navigationDestination(isPresented: $isPresentingCreateAnnouncement) {
            CreateAnnouncementView(
                isPresentedFromHome: $isPresentingCreateAnnouncement
            )
        }
    }

    private func startAnnouncementsListener() {
        announcementsListener?.remove()
        announcementsListener = Firestore.firestore()
            .collection("announcements")
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("❌ Announcer map announcements error: \(error.localizedDescription)")
                    self.mapAnnouncements = []
                    return
                }
                guard let documents = snapshot?.documents else {
                    self.mapAnnouncements = []
                    return
                }

                self.mapAnnouncements = documents.compactMap(parseAnnouncement)
                    .filter { ann in
                        switch ann.displayStatus() {
                        case .pending, .active, .scheduled, .declined:
                            return true
                        case .expired, .removed:
                            return false
                        }
                    }
                    .sorted { $0.createdAt > $1.createdAt }
            }
    }

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
        else { return nil }

        return Announcement(
            id: doc.documentID,
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
    }
}
