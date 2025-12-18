import SwiftUI

struct RootTabView: View {
    @State private var showAnnouncement = false
    
    // Global State for this tab session
    @StateObject private var announcementCenter = AnnouncementCenter()
    @StateObject private var campusMapViewModel = CampusMapViewModel()

    var body: some View {
        ZStack {
            TabView {
                // TAB 1: CAMPUS MAP
                NavigationStack {
                    CampusMapView(showAnnouncement: $showAnnouncement)
                        .navigationTitle("Campus Map")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

                // TAB 2: AR CAMERA
                NavigationStack {
                    ARCameraView()
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("AR Camera", systemImage: "camera.viewfinder")
                }

                // TAB 3: LEADERBOARD
                NavigationStack {
                    LeaderboardView()
                        .navigationTitle("Leaderboard")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Leaderboard", systemImage: "chart.bar.fill")
                }

                // TAB 4: PROFILE
                NavigationStack {
                    ProfileView()
                        .navigationTitle("Profile")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
            }
            .tint(Color.Brand.primary)
            // Injecting objects so all child views can access them
            .environmentObject(announcementCenter)
            .environmentObject(campusMapViewModel)
            .allowsHitTesting(!showAnnouncement)

            // THE ANNOUNCEMENT OVERLAY
            if showAnnouncement {
                AnnouncementOverlay(isShowing: $showAnnouncement)
                    .environmentObject(announcementCenter)
                    .zIndex(1)
            }
        }
    }
}
