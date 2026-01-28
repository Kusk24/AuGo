import Foundation
internal import MapKit
import Combine
import CoreLocation

final class CampusMapViewModel: ObservableObject {

    @Published var posts: [CampusPost] = []  // Not used anymore - kept for backwards compatibility
    @Published var selectedPostID: UUID? = nil
    @Published var clusters: [PostCluster] = []  // Not used anymore - kept for backwards compatibility

    let campusRegion: MKCoordinateRegion

    init() {
        let center = CLLocationCoordinate2D(
            latitude: 13.61194,
            longitude: 100.83700
        )

        campusRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        // Mock posts removed - now using PostManager for real Firebase data
        print("✅ CampusMapViewModel initialized - using PostManager for posts")
    }
    
    // Legacy methods - kept for backwards compatibility but not used
    func toggleSelected(_ post: CampusPost) {
        selectedPostID = selectedPostID == post.id ? nil : post.id
    }
}
