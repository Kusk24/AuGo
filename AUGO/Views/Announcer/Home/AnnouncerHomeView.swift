import SwiftUI

struct AnnouncerHomeView: View {
    @Binding var showAnnouncement: Bool
    
    var body: some View {
        AnnouncerCampusMapView(showAnnouncement: $showAnnouncement)
            .navigationTitle("Campus Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
    }
}
