import SwiftUI
internal import MapKit

struct AnnouncerCampusMapView: View {
    @Binding var showAnnouncement: Bool
    
    @EnvironmentObject var announcementCenter: AnnouncementCenter
    @EnvironmentObject var campusMapViewModel: CampusMapViewModel
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedAnnouncement: Announcement?
    @State private var showSingleAnnouncement = false
    @State private var isPresentingCreateAnnouncement = false
    
    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()
            
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemGray6))
                .shadow(radius: 6)
                .overlay(
                    Map(position: $cameraPosition) {
                        
                        // User location
                        UserAnnotation()
                        
                        // Announcements only
                        ForEach(announcementCenter.announcements) { ann in
                            if let coord = ann.coordinate {
                                Annotation("", coordinate: coord) {
                                    AnnouncementPinView(announcement: ann) {
                                        announcementCenter.markAsRead(ann)
                                        selectedAnnouncement = ann
                                        showSingleAnnouncement = true
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
            cameraPosition = .region(campusMapViewModel.campusRegion)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    announcementCenter.markAllAsRead()
                    showAnnouncement = true
                } label: {
                    Image(systemName:
                        announcementCenter.unreadCount > 0
                        ? "bell.badge.fill"
                        : "bell.fill"
                    )
                    .foregroundColor(Color.Brand.primary)
                }
            }
        }
        .sheet(isPresented: $showSingleAnnouncement) {
            if let ann = selectedAnnouncement {
                SingleAnnouncementView(announcement: ann)
            }
        }
        .navigationDestination(isPresented: $isPresentingCreateAnnouncement) {
            CreateAnnouncementView(
                isPresentedFromHome: $isPresentingCreateAnnouncement
            )
        }
    }
}
