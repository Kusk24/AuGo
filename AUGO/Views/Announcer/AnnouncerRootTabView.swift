import SwiftUI

struct AnnouncerRootTabView: View {
    @State private var showAnnouncement = false
    
    @StateObject private var announcementCenter = AnnouncementCenter()
    @StateObject private var campusMapViewModel = CampusMapViewModel()
    @StateObject private var postManager = PostManager()
    
    var body: some View {
        ZStack {
            TabView {
                
                // HOME
                NavigationStack {
                    AnnouncerHomeView(showAnnouncement: $showAnnouncement)
                        .navigationTitle("Campus Map")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                
                // ANNOUNCEMENTS (later)
                NavigationStack {
                    AnnouncerAnnouncementsView()
                }
                .tabItem {
                    Image(systemName: "megaphone.fill")
                    Text("Announcements")
                }
                
                // PROFILE (later)
                NavigationStack {
                    AnnouncerProfileView()
                        .font(.headline)
                }
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
    }
}
