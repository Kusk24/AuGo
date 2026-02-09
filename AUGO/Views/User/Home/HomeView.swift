import SwiftUI

struct HomeView: View {
    
    @Binding var showAnnouncement: Bool
    
    var body: some View {
        
        // For now, Home = CampusMap
        // Later we can add feed, filters, etc. around it
        CampusMapView(showAnnouncement: $showAnnouncement)
//            .navigationTitle("Campus Map")
//            .navigationBarTitleDisplayMode(.large)
    }
}
