import SwiftUI
import FirebaseAuth
import CoreLocation
import Combine
internal import MapKit

struct CreatePostView: View {
    @Binding var isPresentedFromHome: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var mapViewModel: CampusMapViewModel
    @EnvironmentObject var postManager: PostManager

    @State private var message: String = ""
    @State private var selectedCategory: Post.PostCategory? = nil

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSubmitting = false
    
    @StateObject private var locationManager = LocationManager()

    // Real-time content filtering
    private var contentFilterResult: (contains: Bool, detectedWords: [String]) {
        ContentFilter.containsInappropriateContent(message)
    }
    
    private var hasInappropriateContent: Bool {
        contentFilterResult.contains
    }

    private var canPost: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && selectedCategory != nil
        && !hasInappropriateContent
    }
    
    private var userAvatar: String {
        if let nickname = authManager.userProfile?.nickname {
            return String(nickname.prefix(1)).uppercased()
        }
        return "U"
    }
    
    private var userName: String {
        authManager.userProfile?.nickname ?? "User"
    }

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            VStack(spacing: 12) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // User avatar with initials
                        ZStack {
                            Circle()
                                .fill(Color.Brand.primary.opacity(0.2))
                                .frame(width: 36, height: 36)
                            
                            Text(userAvatar)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.Brand.primary)
                        }

                        Text(userName)
                            .font(.subheadline.bold())

                        Spacer()

                        Menu {
                            ForEach(Post.PostCategory.allCases) { category in
                                Button(category.rawValue) {
                                    selectedCategory = category
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(selectedCategory?.rawValue ?? "Category")
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.Brand.primary.opacity(0.15))
                            .foregroundColor(Color.Brand.primary)
                            .clipShape(Capsule())
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray6))
                            .stroke(hasInappropriateContent ? Color.red : Color.clear, lineWidth: 2)

                        TextEditor(text: $message)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)

                        if message.isEmpty {
                            Text("Share something with the campus.")
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                        }
                    }
                    
                    // Real-time warning for inappropriate content
                    if hasInappropriateContent {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Text("Your message contains inappropriate language. Please remove offensive words.")
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
                )
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
                        Text(isSubmitting ? "Posting..." : "Post")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canPost ? Color.Brand.primary : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!canPost || isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Create Post")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.requestLocation()
        }
        .alert("Post", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    isPresentedFromHome = false
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Submit Post with Current Location
    private func submitPost() async {
        // Check for inappropriate content
        let filterResult = ContentFilter.containsInappropriateContent(message)
        if filterResult.contains {
            alertMessage = ContentFilter.getValidationMessage(for: filterResult.detectedWords)
            showAlert = true
            return
        }
        
        guard let userId = authManager.user?.uid else {
            alertMessage = "Error: User not authenticated"
            showAlert = true
            return
        }
        
        // Get current location or use campus center
        let coordinate: CLLocationCoordinate2D
        if let userLocation = locationManager.location?.coordinate {
            coordinate = userLocation
            print("📍 Using user's current location: \(coordinate.latitude), \(coordinate.longitude)")
        } else {
            coordinate = mapViewModel.campusRegion.center
            print("📍 Using campus center as fallback: \(coordinate.latitude), \(coordinate.longitude)")
        }
        
        isSubmitting = true
        
        do {
            let postId = try await postManager.createPost(
                content: message,
                category: selectedCategory ?? .casual,
                userId: userId,
                coordinate: coordinate
            )
            
            print("✅ Post created with ID: \(postId) at location: \(coordinate.latitude), \(coordinate.longitude)")
            alertMessage = "Post created successfully at your current location!"
            showAlert = true
            isSubmitting = false
            
        } catch {
            alertMessage = "Failed to create post: \(error.localizedDescription)"
            showAlert = true
            isSubmitting = false
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
        print("📍 Location updated: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
