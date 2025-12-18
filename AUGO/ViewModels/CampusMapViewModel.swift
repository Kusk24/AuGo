import Foundation
import MapKit
import Combine // <--- REQUIRED for @Published and ObservableObject

final class CampusMapViewModel: ObservableObject {
    @Published var clusters: [PostCluster] = []
    @Published var selectedPostID: String? = nil
    
    let campusRegion: MKCoordinateRegion

    init() {
        let center = CLLocationCoordinate2D(latitude: 13.61194, longitude: 100.83700)
        campusRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }

    func updateClusters(with posts: [Post]) {
        let radius: CLLocationDistance = 50
        var remaining = posts
        var result: [PostCluster] = []

        while !remaining.isEmpty {
            let base = remaining.removeFirst()
            let baseLoc = CLLocation(latitude: base.latitude, longitude: base.longitude)
            var grouped: [Post] = [base]

            remaining.removeAll { post in
                let loc = CLLocation(latitude: post.latitude, longitude: post.longitude)
                if baseLoc.distance(from: loc) <= radius {
                    grouped.append(post)
                    return true
                }
                return false
            }

            let avgLat = grouped.map { $0.latitude }.reduce(0, +) / Double(grouped.count)
            let avgLon = grouped.map { $0.longitude }.reduce(0, +) / Double(grouped.count)
            result.append(PostCluster(coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon), posts: grouped))
        }
        self.clusters = result
    }

    func toggleSelected(_ post: Post) {
        selectedPostID = (selectedPostID == post.id) ? nil : post.id
    }
}
