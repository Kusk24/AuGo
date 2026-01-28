import SwiftUI
internal import MapKit

struct CreateAnnouncementMapView: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var isPresentedFromHome: Bool

    let title: String
    let content: String
    let link: String?
    let isUrgent: Bool
    let startDate: Date
    let endDate: Date

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

            Map(position: $cameraPosition) {
                UserAnnotation()
            }
            .onMapCameraChange { context in
                center = context.region.center
            }

            Button {
                Task { await submit() }
            } label: {
                Text(isSubmitting ? "Submitting..." : "Submit Announcement")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)
            .padding()
        }
        .onAppear {
            cameraPosition = .region(campusMapViewModel.campusRegion)
        }
        .alert("Announcement", isPresented: $showAlert) {
            Button("OK") {
                dismiss()
                isPresentedFromHome = false
            }
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

        do {
            try await announcementManager.createAnnouncement(
                title: title,
                body: content,
                department: announcer.affiliationName,
                isUrgent: isUrgent,
                link: link,
                startDate: startDate,
                endDate: endDate,
                coordinate: coord,
                announcerName: announcer.name
            )

            alertMessage = "Announcement submitted for approval."
            showAlert = true

        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }

        isSubmitting = false
    }
}
