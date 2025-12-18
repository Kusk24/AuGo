import SwiftUI
import MapKit

struct CreatePostMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresentedFromHome: Bool

    let message: String
    let category: PostCategory

    @EnvironmentObject var mapViewModel: CampusMapViewModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentCenter: CLLocationCoordinate2D?

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            VStack(spacing: 12) {

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.systemGray6))
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                        .overlay(
                            Map(position: $cameraPosition) {
                                UserAnnotation()
                            }
                            .onMapCameraChange { context in
                                currentCenter = context.region.center
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        )

                    // Center marker showing where the post will be
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(colorFor(category))
                }
                .padding(.horizontal)

                Text("Drag the map to adjust where your post will appear.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button {
                    let coord = currentCenter ?? mapViewModel.campusRegion.center
                    mapViewModel.addPost(
                        message: message,
                        category: category,
                        author: "You",
                        at: coord
                    )
                    dismiss()
                    isPresentedFromHome = false
                } label: {
                    Text("Confirm post location")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.Brand.primary)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            cameraPosition = .region(mapViewModel.campusRegion)
        }
        .navigationTitle("Choose Location")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorFor(_ category: PostCategory) -> Color {
        switch category {
        case .casual:
            return .teal
        case .lostFound:
            return .red
        case .complaint:
            return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }
}
