import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseStorage

struct ProfileView: View {
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var themeManager: AppThemeManager

    @State private var showLogoutAlert = false
    @State private var userRank: Int = 0
    @State private var showDeleteAlert = false
    @State private var postToDelete: Post?
    @State private var errorMessage: String?
    @State private var showEconomyAlert = false
    @State private var economyAlertMessage = ""
    
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

    var body: some View {
        ZStack {
            Color.Brand.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Avatar + name
                    VStack(spacing: 12) {
                        // Avatar with initials
                        ZStack {
                            Circle()
                                .fill(Color.Brand.primary.opacity(0.2))
                                .frame(width: 96, height: 96)
                            
                            Text(String(userName.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color.Brand.primary)
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
                    .onAppear {
                        refreshUserRank()
                        
                        // Fetch user posts with real-time listener
                        if let userId = authManager.user?.uid {
                            print("👤 Setting up real-time listener for user posts: \(userId)")
                            postManager.fetchUserPosts(userId: userId)
                            authManager.fetchUserProfile(uid: userId)
                            Task {
                                await postManager.refreshUserEconomy(userId: userId)
                            }
                        }
                    }
                    
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
                                    economyAlertMessage = message
                                    showEconomyAlert = true
                                } catch {
                                    economyAlertMessage = "Failed to claim daily coin: \(error.localizedDescription)"
                                    showEconomyAlert = true
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
                                            postToDelete = post
                                            showDeleteAlert = true
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

                        if capturedCharacters.isEmpty {
                            Text("No captures yet. Catch AR characters to see them here.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(capturedCharacters) { capture in
                                        CapturedCharacterCard(capture: capture)
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
                        showLogoutAlert = true
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
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Delete Post", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                postToDelete = nil
                showDeleteAlert = false
            }
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    postToDelete = nil
                    showDeleteAlert = false
                    Task {
                        await deletePost(post)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this post?")
        }
        .alert("Coins", isPresented: $showEconomyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(economyAlertMessage)
        }
        .onChange(of: authManager.user?.uid) { _, newUserId in
            // Re-setup listener if user changes
            if let userId = newUserId {
                print("👤 User changed, re-setting up listener: \(userId)")
                postManager.fetchUserPosts(userId: userId)
                authManager.fetchUserProfile(uid: userId)
                refreshUserRank()
                Task {
                    await postManager.refreshUserEconomy(userId: userId)
                }
            }
        }
        .onChange(of: authManager.userProfile?.score) { _, _ in
            refreshUserRank()
        }
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
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.85))
                        .font(.system(size: 16, weight: .bold))
                }
            }

            if let resolvedPhotoURL {
                AsyncImage(url: resolvedPhotoURL) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.Brand.surfaceMuted)
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.Brand.surfaceMuted)
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                        .onAppear { schedulePhotoRetry() }
                    @unknown default:
                        EmptyView()
                    }
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
    let capture: ARCapturedCharacter
    @State private var resolvedPreviewURL: URL?
    @State private var isLoadingPreview = false
    @State private var previewRetryCount = 0
    @State private var isPreviewRetryScheduled = false

    private var previewURL: URL? { resolvedPreviewURL }

    private var resolvedPreviewPath: String? {
        if let explicit = normalizedStorageObjectPath(capture.preview), !explicit.isEmpty {
            return explicit
        }
        guard let asset = normalizedStorageObjectPath(capture.assetPath) else { return nil }
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
        if capture.catchCount >= capture.catchableTime {
            return "Maxed · +\(coinsText(capture.coinValue)) coins · +\(capture.pointValue) pts"
        }
        if let next = capture.nextCatchAt, next > Date() {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Next in \(formatter.localizedString(for: next, relativeTo: Date()))"
        }
        return "Ready again · +\(coinsText(capture.coinValue)) coins · +\(capture.pointValue) pts"
    }

    private var progress: Double {
        guard capture.catchableTime > 0 else { return 1 }
        return min(1, Double(capture.catchCount) / Double(capture.catchableTime))
    }

    var body: some View {
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
                    AsyncImage(url: previewURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                        case .failure:
                            placeholderView
                                .onAppear { schedulePreviewRetry() }
                        @unknown default:
                            placeholderView
                        }
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

            Text(capture.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text("\(capture.catchCount)/\(capture.catchableTime) captured")
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView(value: progress)
                .tint(Color.Brand.primary)

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
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.Brand.primary.opacity(0.18))
                    .frame(width: 54, height: 54)
                Text(String(capture.title.prefix(1)).uppercased())
                    .font(.title3.weight(.bold))
                    .foregroundColor(Color.Brand.primary)
            }

            Text("Preview not added")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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

    func invalidateCache(for rawValue: String) {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        resolvedCache.removeValue(forKey: raw)
        for key in objectPathCandidates(from: raw) {
            resolvedCache.removeValue(forKey: key)
        }
    }

    func resolveURL(from rawValue: String) async -> URL? {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let cached = resolvedCache[raw] {
            return cached
        }

        if raw.hasPrefix("https://") || raw.hasPrefix("http://") {
            let direct = URL(string: raw)
            if let direct {
                resolvedCache[raw] = direct
            }
            return direct
        }

        let objectPaths = objectPathCandidates(from: raw)
        for objectPath in objectPaths where !objectPath.isEmpty {
            if let cached = resolvedCache[objectPath] {
                resolvedCache[raw] = cached
                return cached
            }

            do {
                let signedURL = try await signedStorageURL(for: objectPath)
                resolvedCache[objectPath] = signedURL
                resolvedCache[raw] = signedURL
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
            resolvedCache[raw] = fallback
        }
        return fallback
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
