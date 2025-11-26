import SwiftUI

struct RootTabView: View {
    @State private var showAnnouncement = false

    var body: some View {
        ZStack {
            TabView {
                // HOME
                NavigationStack {
                    HomeView(showAnnouncement: $showAnnouncement)
                        .navigationTitle("Campus Map")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

                // AR CAMERA
                NavigationStack {
                    ARCameraView()
                }
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("AR Camera")
                }

                // LEADERBOARD
                NavigationStack {
                    LeaderboardView()
                        .navigationTitle("Leaderboard")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Leaderboard")
                }

                // PROFILE
                NavigationStack {
                    ProfileView()
                        .navigationTitle("Profile")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
            }
            // 👇 selected tab icon + text = Brand.primary
            .tint(Color.Brand.primary)

            // 👇 block interaction when sheet shown
            .allowsHitTesting(!showAnnouncement)

            if showAnnouncement {
                AnnouncementOverlay(isShowing: $showAnnouncement)
                    .zIndex(1)
            }
        }
    }
}
