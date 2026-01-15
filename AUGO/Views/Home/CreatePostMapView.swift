import SwiftUI
internal import MapKit
import FirebaseAuth

struct CreatePostMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresentedFromHome: Bool

    let message: String
    let category: Post.PostCategory

    @EnvironmentObject var mapViewModel: CampusMapViewModel
    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentCenter: CLLocationCoordinate2D?
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""

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
                    Task {
                        await submitPost()
                    }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSubmitting ? "Posting..." : "Confirm & Post")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSubmitting ? Color.gray.opacity(0.5) : Color.Brand.primary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            cameraPosition = .region(mapViewModel.campusRegion)
        }
        .navigationTitle("Choose Location")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Post", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                    isPresentedFromHome = false
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Submit Post to Firebase
    private func submitPost() async {
        guard let userId = authManager.user?.uid else {
            alertMessage = "Error: User not authenticated"
            showAlert = true
            return
        }
        
        isSubmitting = true
        let coordinate = currentCenter ?? mapViewModel.campusRegion.center
        
        do {
            let postId = try await postManager.createPost(
                content: message,
                category: category,
                userId: userId,
                coordinate: coordinate
            )
            
            print("✅ Post created with ID: \(postId) at location: \(coordinate.latitude), \(coordinate.longitude)")
            alertMessage = "Post created successfully!"
            showAlert = true
            isSubmitting = false
            
        } catch {
            alertMessage = "Failed to create post: \(error.localizedDescription)"
            showAlert = true
            isSubmitting = false
        }
    }

    private func colorFor(_ category: Post.PostCategory) -> Color {
        switch category {
        case .casual:
            return .teal
        case .event:
            return .purple
        case .question:
            return .blue
        case .announcement:
            return .orange
        case .arChallenge:
            return .green
        }
    }
}
