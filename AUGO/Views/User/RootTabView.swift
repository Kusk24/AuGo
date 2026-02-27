import SwiftUI
import FirebaseAuth

struct RootTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showAnnouncement = false
    
    @StateObject private var announcementCenter = AnnouncementCenter()
    @StateObject private var campusMapViewModel = CampusMapViewModel()
    @StateObject private var postManager = PostManager()

    var body: some View {
        ZStack {
            TabView {

                // HOME (Campus Map)
                NavigationStack {
                    HomeView(showAnnouncement: $showAnnouncement)
                }
                .toolbar(.visible, for: .navigationBar)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

                // AR CAMERA — NO TITLE (clean fullscreen gameplay)
                NavigationStack {
                    ARCameraView()
                        .toolbar(.hidden, for: .navigationBar)
                }
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("AR Camera")
                }

                // LEADERBOARD
                NavigationStack {
                    LeaderboardView()
                }
                .toolbar(.visible, for: .navigationBar)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Leaderboard")
                }

                // PROFILE
                NavigationStack {
                    ProfileView()
                }
                .toolbar(.visible, for: .navigationBar)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
            }
            .tint(Color.Brand.primary)
            .environmentObject(announcementCenter)
            .environmentObject(campusMapViewModel)
            .environmentObject(postManager)
            .allowsHitTesting(!showAnnouncement)

            if showAnnouncement {
                AnnouncementOverlay(isShowing: $showAnnouncement)
                    .environmentObject(announcementCenter)
                    .zIndex(1)
            }
        }
        .onAppear {
            if let userId = authManager.user?.uid {
                postManager.fetchUserPosts(userId: userId)
            }
        }
        .onChange(of: authManager.user?.uid) { _, newUserID in
            if let userId = newUserID {
                postManager.fetchUserPosts(userId: userId)
            }
        }
    }
}
