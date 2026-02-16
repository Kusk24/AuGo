import SwiftUI
internal import MapKit

struct CreateAnnouncementMapView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @Binding var isPresentedFromHome: Bool
    
    let announcementID: String?
    let title: String
    let content: String
    let link: String?
    let coinReward: Double
    let isUrgent: Bool
    let startDate: Date
    let endDate: Date
    let initialCoordinate: CLLocationCoordinate2D?
    let keptExistingPhotoPaths: [String]
    let photoDatas: [Data]
    let onSubmitSuccess: (() -> Void)?
    
    @EnvironmentObject var campusMapViewModel: CampusMapViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var announcementManager = AnnouncementManager()
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var center: CLLocationCoordinate2D?
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            ZStack {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                }
                .onMapCameraChange { context in
                    center = context.region.center
                }

                VStack(spacing: 8) {
                    Spacer()

                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.Brand.primary)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)

                    if let center {
                        Text(String(format: "Lat %.5f, Lon %.5f", center.latitude, center.longitude))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
            
            Button {
                Task { await submit() }
            } label: {
                Text(isSubmitting ? "Submitting..." : (announcementID == nil ? "Submit Announcement" : "Resubmit Announcement"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || center == nil)
            .padding()
        }
        .onAppear {
            cameraPosition = .region(campusMapViewModel.campusRegion)
            center = initialCoordinate ?? campusMapViewModel.campusRegion.center
            if let initialCoordinate {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: initialCoordinate,
                        span: campusMapViewModel.campusRegion.span
                    )
                )
            }
        }
        .alert("Announcement", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func submit() async {
        guard
            let coord = center,
            let announcer = authManager.announcerProfile
        else { return }
        
        isSubmitting = true
        print("📸 Announcement submit with \(photoDatas.count) photo(s)")
        
        do {
            if let announcementID {
                try await announcementManager.updateAndResubmitAnnouncement(
                    announcementID: announcementID,
                    title: title,
                    body: content,
                    department: announcer.affiliationName,
                    isUrgent: isUrgent,
                    link: link,
                    coinReward: coinReward,
                    startDate: startDate,
                    endDate: endDate,
                    coordinate: coord,
                    keptPhotoPaths: keptExistingPhotoPaths,
                    newPhotoDatas: photoDatas
                )
            } else {
                try await announcementManager.createAnnouncement(
                    title: title,
                    body: content,
                    department: announcer.affiliationName,
                    isUrgent: isUrgent,
                    link: link,
                    coinReward: coinReward,
                    startDate: startDate,
                    endDate: endDate,
                    coordinate: coord,
                    announcerName: announcer.name,
                    photoDatas: photoDatas
                )
            }
            onSubmitSuccess?()
            isPresentedFromHome = false
            dismiss()
            
        } catch {
            print("❌ Announcement submit failed: \(error.localizedDescription)")
            alertMessage = error.localizedDescription
            showAlert = true
        }
        
        isSubmitting = false
    }
}
