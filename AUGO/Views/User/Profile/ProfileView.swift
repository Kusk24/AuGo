import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import FirebaseFirestore
import PhotosUI
import UIKit

struct ProfileView: View {
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var themeManager: AppThemeManager

    @State private var activeAlert: ProfileAlertItem?
    @State private var userRank: Int = 0
    @State private var errorMessage: String?
    @State private var selectedCapturedCharacter: ARCapturedCharacter?
    @State private var selectedCapturePreviewURL: URL?
    @State private var selectedCaptureRarity: String?
    @State private var selectedCaptureDescription: String?
    @State private var spawnCatalogByID: [String: ARSpawnCatalogCharacter] = [:]
    @State private var allCharacters: [ARSpawnCatalogCharacter] = []
    @State private var selectedProfilePhotoItem: PhotosPickerItem?
    @State private var isUploadingProfilePhoto = false
    @State private var showProfileCameraPicker = false
    @State private var resolvedProfileImageURL: URL?
    
    // Computed properties for real user data
    private var userName: String {
        authManager.userProfile?.nickname ?? "User"
    }

    private var fullName: String {
        authManager.userProfile?.name ?? "N/A"
    }
    
    private var studentID: String {
        authManager.userProfile?.studentID ?? "N/A"
    }
    
    private var faculty: String {
        authManager.userProfile?.faculty ?? "N/A"
    }
    
    private var totalPoints: Int {
        authManager.userProfile?.score ?? 0
    }
    
    private var coinBalance: Double {
        postManager.userEconomy?.coinBalance ?? authManager.userProfile?.coinBalance ?? 0
    }
    
    private var freePostsLeft: Int {
        postManager.userEconomy?.freePostsLeft ?? 0
    }
    
    private var dailyFreePostLimit: Int {
        postManager.userEconomy?.dailyFreePostLimit ?? 0
    }
    
    private var canClaimDailyCoin: Bool {
        postManager.userEconomy?.canClaimDailyCoin ?? false
    }
    
    private var dailyCoinReward: Double {
        postManager.userEconomy?.dailyCoinReward ?? 0
    }
    
    private var myPosts: [Post] {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        return postManager.userPosts
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
    }

    private var capturedCharacters: [ARCapturedCharacter] {
        (authManager.userProfile?.arCapturedCharacters ?? [])
            .sorted { ($0.lastCapturedAt ?? .distantPast) > ($1.lastCapturedAt ?? .distantPast) }
    }

    private var capturesBySourceID: [String: ARCapturedCharacter] {
        var merged: [String: ARCapturedCharacter] = [:]
        for capture in capturedCharacters {
            guard let sourceID = sourceSpawnLookupID(for: capture) else { continue }
            if let existing = merged[sourceID] {
                let existingDate = existing.lastCapturedAt ?? .distantPast
                let incomingDate = capture.lastCapturedAt ?? .distantPast
                if incomingDate > existingDate {
                    merged[sourceID] = capture
                }
            } else {
                merged[sourceID] = capture
            }
        }
        return merged
    }

    private var displayedCharacterCollection: [ProfileCharacterCollectionItem] {
        var rows = allCharacters.map { catalog in
            ProfileCharacterCollectionItem(catalog: catalog, capture: capturesBySourceID[catalog.id])
        }

        // Keep captured records visible even if the source spawn is no longer in the current catalog.
        let knownIDs = Set(rows.map(\.id))
        let extraCapturedRows = capturedCharacters.compactMap { capture -> ProfileCharacterCollectionItem? in
            guard let sourceID = sourceSpawnLookupID(for: capture), !knownIDs.contains(sourceID) else { return nil }
            return ProfileCharacterCollectionItem(captureOnly: capture, sourceSpawnID: sourceID)
        }
        rows.append(contentsOf: extraCapturedRows)

        return rows.sorted {
            if $0.isCaptured != $1.isCaptured {
                return $0.isCaptured && !$1.isCaptured
            }
            if let lhsLast = $0.lastCapturedAt, let rhsLast = $1.lastCapturedAt, lhsLast != rhsLast {
                return lhsLast > rhsLast
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func sourceSpawnLookupID(for capture: ARCapturedCharacter) -> String? {
        if let source = capture.sourceSpawnId?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty {
            return source
        }
        if let split = capture.spawnId.split(separator: "@").first, !split.isEmpty {
            return String(split)
        }
        return nil
    }

    private func effectiveRarity(for capture: ARCapturedCharacter) -> String? {
        if let rarity = capture.rarity?.trimmingCharacters(in: .whitespacesAndNewlines), !rarity.isEmpty {
            return rarity
        }
        guard let sourceID = sourceSpawnLookupID(for: capture) else { return nil }
        return spawnCatalogByID[sourceID]?.rarity
    }

    private func effectiveDescription(for capture: ARCapturedCharacter) -> String? {
        if let text = capture.characterDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        guard let sourceID = sourceSpawnLookupID(for: capture) else { return nil }
        return spawnCatalogByID[sourceID]?.description
    }

    var body: some View {
        ZStack {
            Color.Brand.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Avatar + name
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            UserAvatarView(
                                imageURL: resolvedProfileImageURL,
                                fallbackText: userName,
                                size: 96,
                                fillColor: Color.Brand.primary.opacity(0.2),
                                textColor: Color.Brand.primary
                            )

                            Menu {
                                PhotosPicker(selection: $selectedProfilePhotoItem, matching: .images) {
                                    Label("Library", systemImage: "photo.on.rectangle.angled")
                                }

                                Button {
                                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                                        activeAlert = ProfileAlertItem(kind: .message("Profile Picture", "Camera is not available on this device."))
                                        return
                                    }
                                    showProfileCameraPicker = true
                                } label: {
                                    Label("Take Photo", systemImage: "camera.fill")
                                }

                                Button(role: .destructive) {
                                    activeAlert = ProfileAlertItem(kind: .deleteProfilePhoto)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(resolvedProfileImageURL == nil || isUploadingProfilePhoto)
                            } label: {
                                Circle()
                                    .fill(Color.Brand.primary)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "square.and.pencil")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .offset(x:4, y: 2)

                            if isUploadingProfilePhoto {
                                Circle()
                                    .fill(.black.opacity(0.35))
                                    .frame(width: 96, height: 96)
                                    .overlay(
                                        ProgressView()
                                            .tint(.white)
                                    )
                            }
                        }

                        Text(userName)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text(fullName)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Text("Student ID: \(studentID)")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        
                        Text(faculty)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // MARK: Stats cards
                    HStack(spacing: 16) {
                        ProfileStatCard(
                            title: "Total Points",
                            value: "\(totalPoints)"
                        )

                        ProfileStatCard(
                            title: "Rank",
                            value: userRank > 0 ? "#\(userRank)" : "..."
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // MARK: Coins & Daily Posts
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("Coins")
                        
                        Text("Points and coins are separate.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            EconomyInfoCard(
                                title: "Coin Balance",
                                value: coinsText(coinBalance),
                                icon: "bitcoinsign.circle.fill"
                            )
                            EconomyInfoCard(
                                title: "Free Posts Left",
                                value: "\(freePostsLeft)/\(dailyFreePostLimit)",
                                icon: "square.and.pencil"
                            )
                        }
                        
                        Button {
                            guard let userId = authManager.user?.uid else { return }
                            Task {
                                do {
                                    let message = try await postManager.claimDailyLoginCoin(userId: userId)
                                    activeAlert = ProfileAlertItem(kind: .coins(message))
                                } catch {
                                    activeAlert = ProfileAlertItem(kind: .coins("Failed to claim daily coin: \(error.localizedDescription)"))
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "gift.fill")
                                Text(canClaimDailyCoin ? "Claim Daily +\(coinsText(dailyCoinReward)) Coins" : "Daily Coin Already Claimed")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(canClaimDailyCoin ? Color.Brand.primary : Color.gray.opacity(0.25))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!canClaimDailyCoin)
                    }
                    .padding(.horizontal, 16)

                    // MARK: My Posts
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("My Posts")

                        if postManager.isUserPostsLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Loading your posts...")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        } else if myPosts.isEmpty {
                            Text("No posts from the last 24 hours yet.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(myPosts.enumerated()), id: \.offset) { _, post in
                                    TodayPostCard(
                                        post: post,
                                        onDelete: {
                                            activeAlert = ProfileAlertItem(kind: .delete(post))
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // MARK: Captured Characters
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Captured Characters")

                        Text("Your collection of characters")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        if displayedCharacterCollection.isEmpty {
                            Text("No characters available right now.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(displayedCharacterCollection) { character in
                                        CapturedCharacterCard(
                                            character: character,
                                            onTap: { previewURL in
                                                guard let capture = character.capture else { return }
                                                selectedCapturePreviewURL = previewURL
                                                selectedCaptureRarity = effectiveRarity(for: capture)
                                                selectedCaptureDescription = effectiveDescription(for: capture)
                                                selectedCapturedCharacter = capture
                                            }
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // MARK: Settings
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Settings")

                        Text("Manage your account preferences here.")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        HStack {
                            Text("Notification Preferences")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { notificationManager.notificationsEnabled },
                                set: { notificationManager.setNotificationsEnabled($0) }
                            ))
                                .labelsHidden()
                                .tint(Color.Brand.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.Brand.surfaceMuted)
                        )

                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Theme", systemImage: themeManager.mode.iconName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)

                                Spacer()
                            }

                            Picker("Theme", selection: Binding(
                                get: { themeManager.mode },
                                set: { themeManager.setMode($0) }
                            )) {
                                ForEach(AppThemeMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.Brand.surfaceMuted)
                        )
                    }
                    .padding(.horizontal, 16)

                    // MARK: Logout button
                    Button {
                        activeAlert = ProfileAlertItem(kind: .logout)
                    } label: {
                        Text("Logout")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }

        }
        .alert(item: $activeAlert) { alert in
            switch alert.kind {
            case .logout:
                return Alert(
                    title: Text("Logout"),
                    message: Text("Are you sure you want to logout?"),
                    primaryButton: .destructive(Text("Logout")) {
                        authManager.signOut()
                    },
                    secondaryButton: .cancel()
                )
            case .delete(let post):
                return Alert(
                    title: Text("Delete Post"),
                    message: Text("Are you sure you want to delete this post?"),
                    primaryButton: .destructive(Text("Delete")) {
                        Task {
                            await deletePost(post)
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .deleteProfilePhoto:
                return Alert(
                    title: Text("Delete Profile Picture"),
                    message: Text("Remove your current profile picture?"),
                    primaryButton: .destructive(Text("Delete")) {
                        Task { await deleteProfilePhoto() }
                    },
                    secondaryButton: .cancel()
                )
            case .coins(let message):
                return Alert(
                    title: Text("Coins"),
                    message: Text(message),
                    dismissButton: .cancel()
                )
            case .message(let title, let message):
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .sheet(item: $selectedCapturedCharacter, onDismiss: {
            selectedCapturePreviewURL = nil
            selectedCaptureRarity = nil
            selectedCaptureDescription = nil
        }) { capture in
            CapturedCharacterDetailSheet(
                capture: capture,
                imageURL: selectedCapturePreviewURL,
                rarityOverride: selectedCaptureRarity,
                descriptionOverride: selectedCaptureDescription
            )
            .presentationDetents([.fraction(0.78), .large])
            .presentationDragIndicator(.visible)
        }
        .task(id: authManager.user?.uid) {
            guard let userId = authManager.user?.uid else { return }
            refreshUserRank()
            print("👤 Setting up real-time listener for user posts: \(userId)")
            postManager.fetchUserPosts(userId: userId)
            authManager.fetchUserProfile(uid: userId)
            await postManager.refreshUserEconomy(userId: userId)
            await refreshCharacterCatalog()
            await refreshDisplayedProfileImage()
        }
        .task(id: capturedCharacters.map(\.spawnId).joined(separator: "|")) {
            await refreshCharacterCatalog()
        }
        .task(
            id: "\(authManager.userProfile?.profileImageURL ?? "")|\(authManager.userProfile?.profileImagePath ?? "")"
        ) {
            await refreshDisplayedProfileImage()
        }
        .onChange(of: authManager.user?.uid) { _, newUserId in
            // Re-setup listener if user changes
            if let userId = newUserId {
                refreshUserRank()
                print("👤 User changed: \(userId)")
            }
        }
        .onChange(of: authManager.userProfile?.score) { _, _ in
            refreshUserRank()
        }
        .onChange(of: selectedProfilePhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await uploadProfilePhoto(from: newItem) }
        }
        .sheet(isPresented: $showProfileCameraPicker) {
            CameraImagePicker { image in
                Task { await uploadProfilePhoto(image: image) }
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
    
    // MARK: - Delete Post
    private func deletePost(_ post: Post) async {
        guard let postId = post.id else { 
            print("❌ Cannot delete post: missing ID")
            return 
        }
        
        print("🗑️ Attempting to delete post: \(postId)")
        
        // Optimistic update - remove from UI immediately
        postManager.optimisticDeletePost(postId)
        
        do {
            try await postManager.deletePost(postId)
            print("✅ Post deleted successfully: \(postId)")
            // The real-time listener will keep everything in sync
        } catch {
            print("❌ Error deleting post: \(error.localizedDescription)")
            errorMessage = "Failed to delete post: \(error.localizedDescription)"
            // Re-fetch to restore the post if deletion failed
            if let userId = authManager.user?.uid {
                postManager.fetchUserPosts(userId: userId)
            }
        }
    }

    private func refreshUserRank() {
        authManager.fetchUserRank { rank in
            userRank = rank
        }
    }

    private func refreshCharacterCatalog() async {
        let db = Firestore.firestore()
        var parsedCharacters: [ARSpawnCatalogCharacter] = []

        do {
            let snapshot = try await db.collection("ar_spawns").getDocuments()
            parsedCharacters = snapshot.documents.compactMap { document in
                ARSpawnCatalogCharacter.fromDocument(documentID: document.documentID, data: document.data())
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } catch {
            print("❌ Failed loading AR character catalog for profile: \(error.localizedDescription)")
        }

        let byID = Dictionary(uniqueKeysWithValues: parsedCharacters.map { ($0.id, $0) })
        await MainActor.run {
            allCharacters = parsedCharacters
            spawnCatalogByID = byID
        }
    }

    private func uploadProfilePhoto(from item: PhotosPickerItem) async {
        do {
            guard let originalData = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    activeAlert = ProfileAlertItem(kind: .message("Profile Picture", "Failed to read selected image."))
                }
                return
            }

            if let image = UIImage(data: originalData) {
                await uploadProfilePhoto(image: image)
            } else {
                await MainActor.run {
                    activeAlert = ProfileAlertItem(kind: .message("Profile Picture", "Failed to process selected image."))
                }
            }
        } catch {
            await MainActor.run {
                activeAlert = ProfileAlertItem(kind: .message("Profile Picture", "Failed to upload profile picture: \(error.localizedDescription)"))
            }
        }
        await MainActor.run { selectedProfilePhotoItem = nil }
    }

    private func uploadProfilePhoto(image: UIImage) async {
        guard let uid = authManager.user?.uid else { return }
        await MainActor.run { isUploadingProfilePhoto = true }
        defer {
            Task { @MainActor in
                isUploadingProfilePhoto = false
                selectedProfilePhotoItem = nil
            }
        }

        guard let uploadData = image.jpegData(compressionQuality: 0.82) else {
            await MainActor.run {
                activeAlert = ProfileAlertItem(kind: .message("Profile Picture", "Failed to process selected image."))
            }
            return
        }

        do {
            let uploadedURLString = try await authManager.uploadProfileImage(uid: uid, imageData: uploadData)
            await MainActor.run {
                resolvedProfileImageURL = URL(string: uploadedURLString)
                activeAlert = ProfileAlertItem(kind: .message("Profile Picture", "Profile picture updated."))
            }
            await refreshDisplayedProfileImage()
        } catch {
            await MainActor.run {
                activeAlert = ProfileAlertItem(kind: .message("Profile Picture", "Failed to upload profile picture: \(error.localizedDescription)"))
            }
        }
    }

    private func deleteProfilePhoto() async {
        guard let uid = authManager.user?.uid else { return }
        await MainActor.run { isUploadingProfilePhoto = true }
        defer {
            Task { @MainActor in
                isUploadingProfilePhoto = false
            }
        }

        do {
            try await authManager.removeProfileImage(uid: uid)
            await MainActor.run {
                resolvedProfileImageURL = nil
                selectedProfilePhotoItem = nil
                activeAlert = ProfileAlertItem(kind: .message("Profile Picture", "Profile picture deleted."))
            }
        } catch {
            await MainActor.run {
                activeAlert = ProfileAlertItem(kind: .message("Profile Picture", "Failed to delete profile picture: \(error.localizedDescription)"))
            }
        }
    }

    private func refreshDisplayedProfileImage() async {
        var rawCandidates: [String] = []

        if let profileURL = authManager.userProfile?.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !profileURL.isEmpty {
            rawCandidates.append(profileURL)
        }
        if let profilePath = authManager.userProfile?.profileImagePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !profilePath.isEmpty {
            rawCandidates.append(profilePath)
        }
        // Fallback fetch: profile doc can be fresher than local observed model in some sessions.
        if rawCandidates.isEmpty, let uid = authManager.user?.uid {
            do {
                let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
                let data = snapshot.data()
                if let profileURL = data?["profileImageURL"] as? String,
                   !profileURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rawCandidates.append(profileURL)
                }
                if let profilePath = data?["profileImagePath"] as? String,
                   !profilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rawCandidates.append(profilePath)
                }
            } catch {
                print("⚠️ Failed loading profile image fallback doc: \(error.localizedDescription)")
            }
        }

        var uniqueCandidates: [String] = []
        for candidate in rawCandidates {
            if !uniqueCandidates.contains(candidate) {
                uniqueCandidates.append(candidate)
            }
        }

        for candidate in uniqueCandidates {
            if let resolved = await StorageURLResolver.shared.resolveURL(from: candidate) {
                await MainActor.run {
                    resolvedProfileImageURL = resolved
                }
                return
            }
        }

        await MainActor.run {
            resolvedProfileImageURL = nil
        }
    }

}

private struct ARSpawnCatalogCharacter: Identifiable {
    let id: String
    let title: String
    let assetPath: String
    let preview: String?
    let rarity: String?
    let description: String?
    let coinValue: Double
    let pointValue: Int
    let catchableTime: Int

    static func fromDocument(documentID: String, data: [String: Any]) -> ARSpawnCatalogCharacter? {
        let rawTitle = (data["title"] as? String) ?? (data["name"] as? String) ?? ""
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let assetPath = ((data["assetPath"] as? String) ?? (data["modelPath"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = (data["preview"] as? String) ?? (data["previewPath"] as? String)
        let rarity = data["rarity"] as? String
        let description = data["description"] as? String
        let coinValue = toDouble(data["coin_value"]) ?? 0
        let pointValue = toInt(data["point"]) ?? 0
        let catchableTime = max(1, toInt(data["catchable_time"]) ?? 1)

        return ARSpawnCatalogCharacter(
            id: documentID,
            title: title,
            assetPath: assetPath,
            preview: preview,
            rarity: rarity,
            description: description,
            coinValue: coinValue,
            pointValue: pointValue,
            catchableTime: catchableTime
        )
    }

    private static func toDouble(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let floatValue = value as? Float { return Double(floatValue) }
        if let stringValue = value as? String { return Double(stringValue) }
        return nil
    }

    private static func toInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let floatValue = value as? Float { return Int(floatValue) }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }
}

private struct ProfileCharacterCollectionItem: Identifiable {
    let id: String
    let title: String
    let assetPath: String
    let preview: String?
    let rarity: String?
    let description: String?
    let coinValue: Double
    let pointValue: Int
    let catchableTime: Int
    let capture: ARCapturedCharacter?

    var catchCount: Int {
        capture?.catchCount ?? 0
    }

    var lastCapturedAt: Date? {
        capture?.lastCapturedAt
    }

    var isCaptured: Bool {
        capture != nil && catchCount > 0
    }

    init(catalog: ARSpawnCatalogCharacter, capture: ARCapturedCharacter?) {
        self.id = catalog.id
        self.title = capture?.title ?? catalog.title
        self.assetPath = capture?.assetPath ?? catalog.assetPath
        self.preview = capture?.preview ?? catalog.preview
        self.rarity = capture?.rarity ?? catalog.rarity
        self.description = capture?.characterDescription ?? catalog.description
        self.coinValue = capture?.coinValue ?? catalog.coinValue
        self.pointValue = capture?.pointValue ?? catalog.pointValue
        self.catchableTime = max(1, capture?.catchableTime ?? catalog.catchableTime)
        self.capture = capture
    }

    init(captureOnly: ARCapturedCharacter, sourceSpawnID: String) {
        self.id = sourceSpawnID
        self.title = captureOnly.title
        self.assetPath = captureOnly.assetPath
        self.preview = captureOnly.preview
        self.rarity = captureOnly.rarity
        self.description = captureOnly.characterDescription
        self.coinValue = captureOnly.coinValue
        self.pointValue = captureOnly.pointValue
        self.catchableTime = max(1, captureOnly.catchableTime)
        self.capture = captureOnly
    }
}

private struct ProfileAlertItem: Identifiable {
    enum Kind {
        case logout
        case delete(Post)
        case deleteProfilePhoto
        case coins(String)
        case message(String, String)
    }

    let id = UUID()
    let kind: Kind
}

private func coinsText(_ value: Double) -> String {
    String(format: "%.1f", value)
}

// MARK: - Reusable bits

private struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color.Brand.primary)
    }
}

private struct ProfileStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.9))

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.Brand.coin)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct UserAvatarView: View {
    let imageURL: URL?
    let fallbackText: String
    let size: CGFloat
    let fillColor: Color
    let textColor: Color

    private var fallbackInitial: String {
        String(fallbackText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: size, height: size)

            if let imageURL {
                CachedRemoteImage(url: imageURL, cacheKey: imageURL.absoluteString) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    fallbackContent
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                fallbackContent
            }
        }
    }

    private var fallbackContent: some View {
        Text(fallbackInitial.isEmpty ? "U" : fallbackInitial)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundColor(textColor)
    }
}

private struct EconomyInfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Color.Brand.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Brand.surface)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        )
    }
}

private struct TodayPostCard: View {
    let post: Post
    let onDelete: () -> Void
    @State private var resolvedPhotoURL: URL?
    @State private var isLoadingPhoto = false
    @State private var photoRetryCount = 0
    @State private var isPhotoRetryScheduled = false
    
    private var timeAgo: String {
        let interval = Date().timeIntervalSince(post.date)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if days > 0 {
            return "Posted \(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "Posted \(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let minutes = max(1, Int(interval / 60))
            return "Posted \(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }
    }

    private var firstPhotoRawPath: String? { post.photoPaths.first }

    private func loadPhotoURL() async {
        guard let raw = firstPhotoRawPath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            await MainActor.run {
                resolvedPhotoURL = nil
                isLoadingPhoto = false
            }
            return
        }

        await MainActor.run { isLoadingPhoto = true }
        let resolvedURL = await StorageURLResolver.shared.resolveURL(from: raw)

        await MainActor.run {
            resolvedPhotoURL = resolvedURL.map { cacheBustedURL($0, nonce: photoRetryCount) }
            isLoadingPhoto = false
        }
    }

    private func schedulePhotoRetry() {
        guard !isLoadingPhoto,
              !isPhotoRetryScheduled,
              photoRetryCount < 3,
              let raw = firstPhotoRawPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return }

        isPhotoRetryScheduled = true
        photoRetryCount += 1
        resolvedPhotoURL = nil

        Task {
            await StorageURLResolver.shared.invalidateCache(for: raw)
            let delay = UInt64(300_000_000 * max(1, photoRetryCount))
            try? await Task.sleep(nanoseconds: delay)
            await loadPhotoURL()
            await MainActor.run { isPhotoRetryScheduled = false }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 12, height: 12)
                    
                    Text(post.category.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(categoryColor.opacity(0.14))
                )

                if let emoji = post.emojiPin?.trimmingCharacters(in: .whitespacesAndNewlines), !emoji.isEmpty {
                    HStack(spacing: 4) {
                        Text(emoji)
                        Text("Special")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundColor(.pink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.pink.opacity(0.14))
                    )
                }
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.85))
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }

            if let resolvedPhotoURL {
                CachedRemoteImage(url: resolvedPhotoURL, cacheKey: resolvedPhotoURL.absoluteString) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.Brand.surfaceMuted)
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
                    .onAppear { schedulePhotoRetry() }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if isLoadingPhoto {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.Brand.surfaceMuted)
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 170)
            }

            Text(post.content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            HStack {
                Text(timeAgo)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.Brand.surfaceMuted)
                    )
                
                Spacer()
                
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.purple)
                        Text("\(post.likeCount)")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.primary)
                        Text("\(post.dislikeCount)")
                            .font(.subheadline)
                    }
                }
            }            
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.Brand.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
        )
        .task(id: firstPhotoRawPath ?? "") {
            photoRetryCount = 0
            isPhotoRetryScheduled = false
            await loadPhotoURL()
        }
    }
    
    private var categoryColor: Color {
        switch post.category {
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

private struct CapturedCharacterCard: View {
    let character: ProfileCharacterCollectionItem
    let onTap: (URL?) -> Void
    @State private var resolvedPreviewURL: URL?
    @State private var isLoadingPreview = false
    @State private var previewRetryCount = 0
    @State private var isPreviewRetryScheduled = false

    private var previewURL: URL? { resolvedPreviewURL }
    private var isCaptured: Bool { character.isCaptured }

    private var resolvedPreviewPath: String? {
        if let explicit = normalizedStorageObjectPath(character.preview), !explicit.isEmpty {
            return explicit
        }
        guard let asset = normalizedStorageObjectPath(character.assetPath), !asset.isEmpty else { return nil }
        guard let slashIndex = asset.lastIndex(of: "/") else { return nil }
        let folder = asset[..<slashIndex]
        return "\(folder)/preview.png"
    }

    private func loadPreviewURL() async {
        guard let raw = resolvedPreviewPath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            await MainActor.run {
                resolvedPreviewURL = nil
                isLoadingPreview = false
            }
            return
        }

        await MainActor.run { isLoadingPreview = true }
        let resolvedURL = await StorageURLResolver.shared.resolveURL(from: raw)

        await MainActor.run {
            resolvedPreviewURL = resolvedURL.map { cacheBustedURL($0, nonce: previewRetryCount) }
            isLoadingPreview = false
        }
    }

    private func schedulePreviewRetry() {
        guard !isLoadingPreview,
              !isPreviewRetryScheduled,
              previewRetryCount < 3,
              let raw = resolvedPreviewPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return }

        isPreviewRetryScheduled = true
        previewRetryCount += 1
        resolvedPreviewURL = nil

        Task {
            await StorageURLResolver.shared.invalidateCache(for: raw)
            let delay = UInt64(300_000_000 * max(1, previewRetryCount))
            try? await Task.sleep(nanoseconds: delay)
            await loadPreviewURL()
            await MainActor.run { isPreviewRetryScheduled = false }
        }
    }

    private var footerText: String {
        guard let capture = character.capture else {
            return "Not captured yet"
        }
        if capture.catchCount >= max(1, capture.catchableTime) {
            return "Maxed · +\(coinsText(character.coinValue)) coins · +\(character.pointValue) pts"
        }
        if let next = capture.nextCatchAt, next > Date() {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Next \(formatter.localizedString(for: next, relativeTo: Date()))"
        }
        return "Ready again · +\(coinsText(character.coinValue)) coins · +\(character.pointValue) pts"
    }

    private var progress: Double {
        guard character.catchableTime > 0 else { return 1 }
        return min(1, Double(character.catchCount) / Double(character.catchableTime))
    }

    private var rarityText: String? {
        let trimmed = character.rarity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var rarityBadgeColor: Color {
        ARRarityPalette.accentColor(for: rarityText)
    }

    var body: some View {
        Button {
            guard isCaptured else { return }
            onTap(previewURL)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.Brand.primary.opacity(0.18), Color.Brand.primary.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    if let previewURL {
                        CachedRemoteImage(url: previewURL, cacheKey: previewURL.absoluteString) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                        } placeholder: {
                            placeholderView
                                .onAppear { schedulePreviewRetry() }
                        }
                    } else if isLoadingPreview {
                        ProgressView()
                    } else {
                        placeholderView
                    }
                }
                .frame(height: 156)
                .task(id: resolvedPreviewPath ?? "") {
                    previewRetryCount = 0
                    isPreviewRetryScheduled = false
                    await loadPreviewURL()
                }
                .saturation(isCaptured ? 1 : 0)

                Text(character.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundColor(isCaptured ? .primary : .secondary)

                if let rarity = rarityText {
                    Text(rarity)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(isCaptured ? rarityBadgeColor : .gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.26))
                        .clipShape(Capsule())
                }

                Text("\(character.catchCount)/\(character.catchableTime) captured")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProgressView(value: progress)
                    .tint(isCaptured ? Color.Brand.primary : .gray)

                Text(footerText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 180, height: 332, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.Brand.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isCaptured ? Color.primary.opacity(0.08) : Color.gray.opacity(0.22),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .saturation(isCaptured ? 1 : 0)
            .opacity(isCaptured ? 1 : 0.84)
        }
        .buttonStyle(.plain)
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.Brand.primary.opacity(0.18))
                    .frame(width: 54, height: 54)
                Text(String(character.title.prefix(1)).uppercased())
                    .font(.title3.weight(.bold))
                    .foregroundColor(Color.Brand.primary)
            }

            Text("Preview not added")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

private struct CapturedCharacterDetailSheet: View {
    let capture: ARCapturedCharacter
    let imageURL: URL?
    let rarityOverride: String?
    let descriptionOverride: String?
    @Environment(\.dismiss) private var dismiss

    private var subtitle: String {
        let countText = "Captured \(capture.catchCount)/\(capture.catchableTime)"
        guard let last = capture.lastCapturedAt else {
            return countText
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "\(countText) · \(formatter.localizedString(for: last, relativeTo: Date()))"
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Captured Character")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.top, 14)
            .padding(.horizontal, 8)

            HolographicCaptureCard(
                title: capture.title,
                subtitle: subtitle,
                descriptionText: descriptionOverride ?? capture.characterDescription,
                rarity: rarityOverride ?? capture.rarity,
                imageURL: imageURL,
                coinText: "+\(coinsText(capture.coinValue))",
                pointsText: "+\(capture.pointValue) pts"
            )
            .frame(maxWidth: 340)
            .padding(.top, 2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(Color.Brand.appBackground.ignoresSafeArea())
    }
}

private func firebaseMediaURL(from rawValue: String) -> URL? {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }

    if value.hasPrefix("https://") || value.hasPrefix("http://") {
        return URL(string: value)
    }

    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    if value.hasPrefix("gs://"),
       let gsURL = URL(string: value),
       let bucket = gsURL.host {
        var objectPath = gsURL.path
        while objectPath.hasPrefix("/") {
            objectPath.removeFirst()
        }
        guard let escapedPath = objectPath.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
    }

    guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else { return nil }
    var objectPath = value
    while objectPath.hasPrefix("/") {
        objectPath.removeFirst()
    }
    guard let escapedPath = objectPath.addingPercentEncoding(withAllowedCharacters: allowed) else {
        return nil
    }
    return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
}

private func normalizedStorageObjectPath(_ rawValue: String?) -> String? {
    guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }
    if value.hasPrefix("gs://"), let gsURL = URL(string: value) {
        value = gsURL.path
    }
    while value.hasPrefix("/") {
        value.removeFirst()
    }
    return value.isEmpty ? nil : value
}

private func storageObjectPathCandidates(from rawValue: String) -> [String] {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    var candidates: [String] = []

    if let normalized = normalizedStorageObjectPath(trimmed) {
        candidates.append(normalized)
    }

    if (trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://")),
       let components = URLComponents(string: trimmed),
       let range = components.path.range(of: "/o/") {
        let encodedObject = String(components.path[range.upperBound...])
        let decoded = encodedObject.removingPercentEncoding ?? encodedObject
        if let normalized = normalizedStorageObjectPath(decoded) {
            candidates.append(normalized)
        }
    }

    if let decoded = trimmed.removingPercentEncoding,
       decoded != trimmed,
       let normalized = normalizedStorageObjectPath(decoded) {
        candidates.append(normalized)
    }

    var unique: [String] = []
    for candidate in candidates where !candidate.isEmpty {
        if !unique.contains(candidate) {
            unique.append(candidate)
        }
    }
    return unique
}

private func storageMediaURL(forObjectPath objectPath: String) -> URL? {
    guard !objectPath.isEmpty else { return nil }
    guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else { return nil }
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    guard let escapedPath = objectPath.addingPercentEncoding(withAllowedCharacters: allowed) else {
        return nil
    }
    return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
}

private actor StorageURLResolver {
    static let shared = StorageURLResolver()

    private var resolvedCache: [String: URL] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheEntries = 600

    func invalidateCache(for rawValue: String) {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        removeCachedURL(for: raw)
        for key in objectPathCandidates(from: raw) {
            removeCachedURL(for: key)
        }
    }

    func resolveURL(from rawValue: String) async -> URL? {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let cached = cachedURL(for: raw) {
            return cached
        }

        if raw.hasPrefix("https://") || raw.hasPrefix("http://") {
            let direct = URL(string: raw)
            if let direct {
                storeCachedURL(direct, for: raw)
            }
            return direct
        }

        let objectPaths = objectPathCandidates(from: raw)
        for objectPath in objectPaths where !objectPath.isEmpty {
            if let cached = cachedURL(for: objectPath) {
                storeCachedURL(cached, for: raw)
                return cached
            }

            do {
                let signedURL = try await signedStorageURL(for: objectPath)
                storeCachedURL(signedURL, for: objectPath)
                storeCachedURL(signedURL, for: raw)
                return signedURL
            } catch {
                continue
            }
        }

        // For private Storage files, unsigned media URLs frequently fail.
        // If we had an object path but couldn't get a signed URL, return nil and retry.
        if !objectPaths.isEmpty {
            return nil
        }

        let fallback = mediaURL(fromRaw: raw)

        if let fallback {
            storeCachedURL(fallback, for: raw)
        }
        return fallback
    }

    private func cachedURL(for key: String) -> URL? {
        guard let value = resolvedCache[key] else { return nil }
        touchKey(key)
        return value
    }

    private func storeCachedURL(_ url: URL, for key: String) {
        resolvedCache[key] = url
        touchKey(key)
        evictIfNeeded()
    }

    private func removeCachedURL(for key: String) {
        resolvedCache.removeValue(forKey: key)
        cacheOrder.removeAll(where: { $0 == key })
    }

    private func touchKey(_ key: String) {
        cacheOrder.removeAll(where: { $0 == key })
        cacheOrder.append(key)
    }

    private func evictIfNeeded() {
        guard resolvedCache.count > maxCacheEntries else { return }
        let overflow = resolvedCache.count - maxCacheEntries
        guard overflow > 0 else { return }

        let keysToRemove = Array(cacheOrder.prefix(overflow))
        for key in keysToRemove {
            resolvedCache.removeValue(forKey: key)
        }
        cacheOrder.removeFirst(min(overflow, cacheOrder.count))
    }

    private func signedStorageURL(for objectPath: String) async throws -> URL {
        let ref = Storage.storage().reference(withPath: objectPath)
        do {
            return try await ref.downloadURL()
        } catch {
            // One retry helps with transient network/auth hiccups that affect only some cards.
            try await Task.sleep(nanoseconds: 200_000_000)
            return try await ref.downloadURL()
        }
    }

    private func mediaURL(fromRaw rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("https://") || value.hasPrefix("http://") {
            return URL(string: value)
        }

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

        if value.hasPrefix("gs://"),
           let gsURL = URL(string: value),
           let bucket = gsURL.host {
            var objectPath = gsURL.path
            while objectPath.hasPrefix("/") {
                objectPath.removeFirst()
            }
            guard let escapedPath = objectPath.addingPercentEncoding(withAllowedCharacters: allowed) else {
                return nil
            }
            return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
        }

        guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else { return nil }
        var objectPath = value
        while objectPath.hasPrefix("/") {
            objectPath.removeFirst()
        }
        guard let escapedPath = objectPath.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
    }

    private func objectPathCandidates(from rawValue: String) -> [String] {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates: [String] = []

        if let normalized = normalizedStorageObjectPath(trimmed) {
            candidates.append(normalized)
        }

        if (trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://")),
           let components = URLComponents(string: trimmed),
           let range = components.path.range(of: "/o/") {
            let encodedObject = String(components.path[range.upperBound...])
            let decoded = encodedObject.removingPercentEncoding ?? encodedObject
            if let normalized = normalizedStorageObjectPath(decoded) {
                candidates.append(normalized)
            }
        }

        if let decoded = trimmed.removingPercentEncoding,
           decoded != trimmed,
           let normalized = normalizedStorageObjectPath(decoded) {
            candidates.append(normalized)
        }

        var unique: [String] = []
        for candidate in candidates where !candidate.isEmpty {
            if !unique.contains(candidate) {
                unique.append(candidate)
            }
        }
        return unique
    }

    private func normalizedStorageObjectPath(_ rawValue: String?) -> String? {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("gs://"), let gsURL = URL(string: value) {
            value = gsURL.path
        }
        while value.hasPrefix("/") {
            value.removeFirst()
        }
        return value.isEmpty ? nil : value
    }

}

private func cacheBustedURL(_ url: URL, nonce: Int) -> URL {
    guard nonce > 0 else { return url }
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
    var items = components.queryItems ?? []
    items.removeAll(where: { $0.name == "cb" })
    items.append(URLQueryItem(name: "cb", value: "\(nonce)"))
    components.queryItems = items
    return components.url ?? url
}
