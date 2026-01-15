import Foundation
internal import MapKit
import Combine
import CoreLocation

final class CampusMapViewModel: ObservableObject {

    @Published var posts: [CampusPost] = []
    @Published var selectedPostID: UUID? = nil
    @Published var clusters: [PostCluster] = []

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

        seedMockPosts(around: center)
        rebuildClusters()
    }

    private func seedMockPosts(around center: CLLocationCoordinate2D) {
        posts = [
            CampusPost(
                author: "Sam",
                message: "Free snacks in front of AU Mall right now 🍩",
                coordinate: offset(center, dLat: 0.0008, dLon: 0.0002),
                category: .casual,
                createdAt: Date()
            ),
            CampusPost(
                author: "Noel",
                message: "Lost AirPods near CL building. Please DM 🙏",
                coordinate: offset(center, dLat: -0.0005, dLon: 0.0003),
                category: .lostFound,
                createdAt: Date().addingTimeInterval(-60 * 45)
            ),
            CampusPost(
                author: "Win",
                message: "Traffic at the main gate is crazy rn 😵‍💫",
                coordinate: offset(center, dLat: 0.0001, dLon: -0.0006),
                category: .complaint,
                createdAt: Date().addingTimeInterval(-60 * 90)
            )
        ]
    }

    private func offset(_ coord: CLLocationCoordinate2D,
                        dLat: Double,
                        dLon: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coord.latitude + dLat,
            longitude: coord.longitude + dLon
        )
    }

    func toggleSelected(_ post: CampusPost) {
        selectedPostID = selectedPostID == post.id ? nil : post.id
    }

    func addPost(
        message: String,
        category: PostCategory,
        author: String = "You",
        at coordinate: CLLocationCoordinate2D
    ) {
        posts.append(
            CampusPost(
                author: author,
                message: message,
                coordinate: coordinate,
                category: category,
                createdAt: Date()
            )
        )
        rebuildClusters()
    }

    // 🔥 CLUSTER LOGIC
    func rebuildClusters() {
        let radius: CLLocationDistance = 50
        var remaining = posts
        var result: [PostCluster] = []

        while !remaining.isEmpty {
            let base = remaining.removeFirst()
            let baseLoc = CLLocation(
                latitude: base.coordinate.latitude,
                longitude: base.coordinate.longitude
            )

            var grouped: [CampusPost] = [base]

            remaining.removeAll { post in
                let loc = CLLocation(
                    latitude: post.coordinate.latitude,
                    longitude: post.coordinate.longitude
                )
                if baseLoc.distance(from: loc) <= radius {
                    grouped.append(post)
                    return true
                }
                return false
            }

            let avgLat = grouped.map { $0.coordinate.latitude }.reduce(0, +) / Double(grouped.count)
            let avgLon = grouped.map { $0.coordinate.longitude }.reduce(0, +) / Double(grouped.count)

            result.append(
                PostCluster(
                    coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    posts: grouped
                )
            )
        }

        clusters = result
    }
}
