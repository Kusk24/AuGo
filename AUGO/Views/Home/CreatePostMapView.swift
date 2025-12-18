import SwiftUI
import MapKit
import FirebaseAuth

struct CreatePostMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresentedFromHome: Bool
    
    let content: String
    let category: Post.Category

    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var mapViewModel: CampusMapViewModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentCenter: CLLocationCoordinate2D?
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                UserAnnotation()
            }
            .onMapCameraChange { context in
                currentCenter = context.region.center
            }
            .ignoresSafeArea(edges: .bottom)

            // Center Pin Indicator
            VStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(colorFor(category))
                    .shadow(radius: 2)
                Spacer().frame(height: 40)
            }

            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Drag the map to set post location")
                        .font(.caption).bold()
                        .padding(8)
                        .background(.white.opacity(0.8))
                        .cornerRadius(8)
                    
                    Button {
                        submitPost()
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Confirm & Post")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.Brand.primary)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            cameraPosition = .region(mapViewModel.campusRegion)
        }
        .navigationTitle("Set Location")
    }

    private func submitPost() {
        guard let userId = authManager.user?.uid else { return }
        let coord = currentCenter ?? mapViewModel.campusRegion.center
        isSubmitting = true
        
        Task {
            do {
                _ = try await postManager.createPost(
                    content: content,
                    category: category,
                    userId: userId,
                    coordinate: coord
                )
                await MainActor.run {
                    isSubmitting = false
                    isPresentedFromHome = false
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    print("Error creating post: \(error.localizedDescription)")
                }
            }
        }
    }

    private func colorFor(_ category: Post.Category) -> Color {
        switch category {
        case .casual: return .teal
        case .lostFound: return .red
        case .complaint: return .yellow
        case .event: return .purple
        case .question: return .blue
        case .announcement: return .orange
        case .arChallenge: return .green
        }
    }
}
