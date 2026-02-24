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
    
    private var coinBalance: Double {
        postManager.userEconomy?.coinBalance ?? authManager.userProfile?.coinBalance ?? 0
    }
    
    private var freePostsLeft: Int {
        postManager.userEconomy?.freePostsLeft ?? 0
    }
    
    private var freePostLimit: Int {
        postManager.userEconomy?.dailyFreePostLimit ?? 0
    }

    private var accountPostingRestriction: String? {
        authManager.postingRestrictionMessage
    }

    var body: some View {
        ZStack {
            Color.Brand.appBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.Brand.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
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
                
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundColor(.orange)
                        Text("Coins: \(coinsText(coinBalance))")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                    
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(Color.Brand.primary)
                        Text("Free posts left: \(freePostsLeft)/\(freePostLimit)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.Brand.primary.opacity(0.12))
                    .clipShape(Capsule())
                }

                if let accountPostingRestriction {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(accountPostingRestriction)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

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
                .disabled(isSubmitting || accountPostingRestriction != nil)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            cameraPosition = .region(mapViewModel.campusRegion)
            if let userId = authManager.user?.uid {
                Task {
                    await postManager.refreshUserEconomy(userId: userId)
                }
            }
        }
        .navigationTitle("Choose Location")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Post", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Submit Post to Firebase
    private func submitPost() async {
        if let accountPostingRestriction {
            alertMessage = accountPostingRestriction
            showAlert = true
            return
        }

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
            isPresentedFromHome = false
            dismiss()
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
            return .yellow
        case .lostFound:
            return .teal
        case .complaint:
            return .purple
        case .event:
            return .orange
        case .question:
            return .blue
        case .arChallenge:
            return .green
        }
    }
}

private func coinsText(_ value: Double) -> String {
    String(format: "%.1f", value)
}
