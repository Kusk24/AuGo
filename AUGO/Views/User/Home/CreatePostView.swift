import SwiftUI
import FirebaseAuth
import CoreLocation
import Combine
internal import MapKit
import PhotosUI

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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhoto: UIImage?
    @State private var isLoadingPhotos = false
    @State private var enableEmojiPin = false
    @State private var selectedEmojiPin: String?
    
    @StateObject private var locationManager = LocationManager()
    
    private let postEmojis = ["😀", "🔥", "🎉", "❓", "⚠️", "📦", "🙏", "💬", "😢", "🆘"]

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
        && (!enableEmojiPin || selectedEmojiPin != nil)
        && !hasInappropriateContent
        && accountPostingRestriction == nil
    }

    private var accountPostingRestriction: String? {
        authManager.postingRestrictionMessage
    }

    private var accountRestrictionTint: Color {
        switch authManager.userProfile?.status {
        case .banned:
            return .red
        case .suspended:
            return .orange
        default:
            return .red
        }
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
    
    private var coinBalance: Double {
        postManager.userEconomy?.coinBalance ?? authManager.userProfile?.coinBalance ?? 0
    }
    
    private var freePostsLeft: Int {
        postManager.userEconomy?.freePostsLeft ?? 0
    }
    
    private var freePostLimit: Int {
        postManager.userEconomy?.dailyFreePostLimit ?? 0
    }
    
    private var emojiPinPrice: Double {
        postManager.userEconomy?.emojiPinPrice ?? 0
    }
    
    private var categoryOptions: [Post.PostCategory] {
        [.casual, .lostFound, .complaint, .event, .question, .arChallenge]
    }

    var body: some View {
        ZStack {
            Color.Brand.appBackground
                .ignoresSafeArea()

            ScrollView {
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
                            ForEach(categoryOptions) { category in
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
                            Image(systemName: "shield.lefthalf.filled.slash")
                                .foregroundColor(accountRestrictionTint)
                            Text(accountPostingRestriction)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(accountRestrictionTint)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(accountRestrictionTint.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.Brand.surfaceMuted)
                            .stroke(hasInappropriateContent ? Color.red : Color.clear, lineWidth: 2)

                        TextEditor(text: $message)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)

                        if message.isEmpty {
                            Text("Share something with the campus.")
                                .foregroundColor(.secondary)
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

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Photos")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(selectedPhoto == nil ? "0/1" : "1/1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text(selectedPhoto == nil ? "Add photo" : "Replace photo")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.Brand.primary.opacity(0.12))
                            .foregroundColor(Color.Brand.primary)
                            .clipShape(Capsule())
                        }

                        if isLoadingPhotos {
                            ProgressView("Loading photo...")
                                .font(.caption)
                        }

                        if let selectedPhoto {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedPhoto)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    self.selectedPhoto = nil
                                    self.selectedPhotoItem = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(Circle())
                                }
                                .offset(x: 6, y: -6)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle(isOn: $enableEmojiPin) {
                                Text("Post with emoji (Special Post)")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .tint(Color.Brand.primary)

                            Spacer()
                            Label("\(coinsText(emojiPinPrice))", systemImage: "bitcoinsign.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        if enableEmojiPin {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(postEmojis, id: \.self) { emoji in
                                        Button {
                                            selectedEmojiPin = emoji
                                        } label: {
                                            Text(emoji)
                                                .font(.system(size: 24))
                                                .frame(width: 44, height: 44)
                                                .background((selectedEmojiPin == emoji ? Color.Brand.primary.opacity(0.22) : Color.Brand.surfaceMuted))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            Text("Emoji pins are shown on map instead of SF symbols.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: enableEmojiPin) { _, enabled in
                        if enabled, selectedEmojiPin == nil {
                            selectedEmojiPin = postEmojis.first
                        }
                        if !enabled {
                            selectedEmojiPin = nil
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.Brand.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
                )
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Create Post")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack {
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
                    .padding(.vertical, 12)
                    .background(canPost ? Color.Brand.primary : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canPost || isSubmitting)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            print("🔐 Requesting location permission...")
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
            
            // Give a moment for location to update
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let location = locationManager.lastLocation {
                    print("✅ Location obtained: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                } else {
                    print("⚠️ Location not available yet, will use fallback if needed")
                }
            }
            
            if let userId = authManager.user?.uid {
                Task {
                    await postManager.refreshUserEconomy(userId: userId)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                await loadSelectedPhoto(from: item)
            }
        }
        .alert("Post", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Submit Post with Current Location
    private func submitPost() async {
        if let accountPostingRestriction {
            alertMessage = accountPostingRestriction
            showAlert = true
            return
        }

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
        if let userLocation = locationManager.lastLocation?.coordinate {
            coordinate = userLocation
            print("📍 Using user's current location: \(coordinate.latitude), \(coordinate.longitude)")
        } else {
            coordinate = mapViewModel.campusRegion.center
            print("📍 Using campus center as fallback: \(coordinate.latitude), \(coordinate.longitude)")
        }
        
        isSubmitting = true
        
        do {
            let photoData = selectedPhoto?.jpegData(compressionQuality: 0.82)
            let postId = try await postManager.createPost(
                content: message,
                category: selectedCategory ?? .casual,
                userId: userId,
                coordinate: coordinate,
                photoData: photoData,
                emojiPin: enableEmojiPin ? selectedEmojiPin : nil
            )
            
            print("✅ Post created with ID: \(postId) at location: \(coordinate.latitude), \(coordinate.longitude)")
            isPresentedFromHome = false
            isSubmitting = false
            
        } catch let creationError as PostManager.PostCreationError {
            alertMessage = creationError.localizedDescription
            showAlert = true
            isSubmitting = false
        } catch {
            let errorText = (error as NSError).localizedDescription
            if errorText.localizedCaseInsensitiveContains("missing or insufficient permissions") {
                alertMessage = "You cannot create a post right now due to account restrictions."
            } else {
                alertMessage = "Failed to create post: \(errorText)"
            }
            showAlert = true
            isSubmitting = false
        }
    }

    @MainActor
    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        guard let item else {
            selectedPhoto = nil
            return
        }

        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedPhoto = image
        } else {
            selectedPhoto = nil
        }
    }
}

private func coinsText(_ value: Double) -> String {
    String(format: "%.1f", value)
}
