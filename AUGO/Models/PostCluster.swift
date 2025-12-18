import Foundation
import CoreLocation

struct PostCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let posts: [CampusPost]

    var count: Int {
        posts.count
    }
}
