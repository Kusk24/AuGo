import SwiftUI
internal import MapKit
import FirebaseAuth
import FirebaseFirestore

private enum CampusMapSheet: Identifiable {
    case announcement
    case cluster
    case postDetail

    var id: Int {
        switch self {
        case .announcement: return 1
        case .cluster: return 2
        case .postDetail: return 3
        }
    }
}

struct CampusMapView: View {
    @Binding var showAnnouncement: Bool

    @EnvironmentObject var viewModel: CampusMapViewModel
    @EnvironmentObject var announcementCenter: AnnouncementCenter
    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var cameraPosition: MapCameraPosition = .automatic

    @State private var selectedAnnouncement: Announcement?

    @State private var isPresentingCreatePost = false

    @State private var selectedCluster: PostCluster?
    @State private var activeSheet: CampusMapSheet?
    
    @State private var selectedPostID: UUID? = nil
    @State private var postMapping: [UUID: Post] = [:]
    @State private var postByDocumentID: [String: Post] = [:]
    @State private var userDisplayNames: [String: String] = [:]
    @State private var loadingUserDisplayNameIDs: Set<String> = []
    @State private var pendingSelectedPost: CampusPost?
    @State private var selectedPostDocumentID: String?
    
    @State private var showReportAlert = false
    @State private var postToReport: Post?    
    @State private var selectedPost: CampusPost?
    @State private var showSuccessAlert = false
    @State private var alertMessage = ""
    @State private var showNotificationList = false
    // MARK: - FILTER
    @State private var selectedCategories: Set<Post.PostCategory> = Set([
        .casual, .lostFound, .complaint, .event, .question, .arChallenge
    ])
    @State private var specialOnlyFilterEnabled = false
    @State private var displayClusters: [PostCluster] = []
    @State private var arSpawnDots: [ARSpawnMapDot] = []
    @State private var arSpawnsListener: ListenerRegistration?

    private var defaultMapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: viewModel.campusRegion.center,
            span: MKCoordinateSpan(
                latitudeDelta: viewModel.campusRegion.span.latitudeDelta * 1.15,
                longitudeDelta: viewModel.campusRegion.span.longitudeDelta * 1.15
            )
        )
    }
    
    private func updateClustersAndMapping(posts: [Post]? = nil) {
        let postsToUse = posts ?? postManager.allPosts
        let filtered = postsToUse.filter { selectedCategories.contains($0.category) }
        let modeFiltered = specialOnlyFilterEnabled
            ? filtered.filter { isSpecialEmojiPost($0) }
            : filtered
        
        let userIDs = Set(modeFiltered.map(\.userId))
        let missingUserIDs = userIDs.filter { userDisplayNames[$0] == nil && !loadingUserDisplayNameIDs.contains($0) }
        if !missingUserIDs.isEmpty {
            loadingUserDisplayNameIDs.formUnion(missingUserIDs)
            let missing = Array(missingUserIDs)
            Task {
                await ensureUserDisplayNames(for: missing)
            }
        }

        let (clusters, mapping) = specialOnlyFilterEnabled
            ? createSpecialClusters(from: modeFiltered)
            : createClusters(from: modeFiltered)

        displayClusters = clusters
        postMapping = mapping
        postByDocumentID = Dictionary(uniqueKeysWithValues: modeFiltered.compactMap { post in
            guard let id = post.id else { return nil }
            return (id, post)
        })
    }

    private var categoryFilterOptions: [Post.PostCategory] {
        [.casual, .lostFound, .complaint, .event, .question, .arChallenge]
    }
    
    private func createClusters(from posts: [Post]) -> ([PostCluster], [UUID: Post]) {
        let radius: CLLocationDistance = 50
        var remaining = posts
        var result: [PostCluster] = []
        var newMapping: [UUID: Post] = [:]

        while !remaining.isEmpty {
            let base = remaining.removeFirst()
            let baseLoc = CLLocation(latitude: base.latitude, longitude: base.longitude)
            
            let campusPost = CampusPost(
                sourcePostID: base.id,
                author: displayName(for: base.userId),
                message: base.content,
                coordinate: base.coordinate,
                category: convertCategory(base.category),
                createdAt: base.date,
                emojiPin: base.emojiPin
            )
            
            newMapping[campusPost.id] = base
            var grouped: [CampusPost] = [campusPost]

            remaining.removeAll { post in
                let loc = CLLocation(latitude: post.latitude, longitude: post.longitude)
                if baseLoc.distance(from: loc) < radius {
                    let cp = CampusPost(
                        sourcePostID: post.id,
                        author: displayName(for: post.userId),
                        message: post.content,
                        coordinate: post.coordinate,
                        category: convertCategory(post.category),
                        createdAt: post.date,
                        emojiPin: post.emojiPin
                    )
                    newMapping[cp.id] = post
                    grouped.append(cp)
                    return true
                }
                return false
            }

            result.append(PostCluster(coordinate: grouped[0].coordinate, posts: grouped))
        }

        return (result, newMapping)
    }

    private func createSpecialClusters(from posts: [Post]) -> ([PostCluster], [UUID: Post]) {
        var mapping: [UUID: Post] = [:]
        let clusters: [PostCluster] = posts.enumerated().map { index, post in
            let offset = Double(index % 5) * 0.00001
            let displayCoordinate = CLLocationCoordinate2D(
                latitude: post.coordinate.latitude + offset,
                longitude: post.coordinate.longitude - offset
            )
            let campusPost = CampusPost(
                sourcePostID: post.id,
                author: displayName(for: post.userId),
                message: post.content,
                coordinate: displayCoordinate,
                category: convertCategory(post.category),
                createdAt: post.date,
                emojiPin: post.emojiPin
            )
            mapping[campusPost.id] = post
            return PostCluster(coordinate: campusPost.coordinate, posts: [campusPost])
        }
        return (clusters, mapping)
    }

    private func isSpecialEmojiPost(_ post: Post) -> Bool {
        let emoji = post.emojiPin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !emoji.isEmpty
    }
    
    private func displayName(for userId: String) -> String {
        if let displayName = userDisplayNames[userId], !displayName.isEmpty {
            return displayName
        }
        return userId
    }
    
    private func buildDisplayName(from data: [String: Any], fallbackId: String) -> String {
        let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nickname = (data["nickname"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if !name.isEmpty && !nickname.isEmpty {
            return "\(name) (\(nickname))"
        }
        if !name.isEmpty { return name }
        if !nickname.isEmpty { return nickname }
        return fallbackId
    }
    
    private func ensureUserDisplayNames(for userIDs: [String]) async {
        guard !userIDs.isEmpty else { return }
        
        let db = Firestore.firestore()
        var resolvedNames: [String: String] = [:]
        
        for chunk in userIDs.chunked(into: 10) {
            do {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                
                for document in snapshot.documents {
                    let data = document.data()
                    resolvedNames[document.documentID] = buildDisplayName(from: data, fallbackId: document.documentID)
                }
            } catch {
                print("❌ Failed loading user display names: \(error.localizedDescription)")
            }
        }
        
        for id in userIDs where resolvedNames[id] == nil {
            resolvedNames[id] = id
        }

        await MainActor.run {
            userDisplayNames.merge(resolvedNames) { _, new in new }
            loadingUserDisplayNameIDs.subtract(userIDs)
            updateClustersAndMapping()
        }
    }
    
    // MARK: - Helper Methods
    
    private func reportPost(category: Report.ReportCategory) {
        guard let post = postToReport,
              let userId = authManager.user?.uid,
              let postId = post.id else {
            print("❌ Missing required data for report: post=\(postToReport != nil), userId=\(authManager.user?.uid != nil)")
            alertMessage = "Failed to report: Missing data"
            showSuccessAlert = true
            return
        }
        
        let reporterName = authManager.userProfile?.name ?? authManager.user?.displayName ?? "Unknown"
        print("🚨 Reporting post \(postId) with category \(category.rawValue) by \(reporterName)")
        
        Task {
            do {
                try await postManager.reportPost(
                    postId,
                    category: category,
                    reportedBy: userId,
                    reporterName: reporterName,
                    post: post
                )
                print("✅ Report submitted successfully")
                
                await MainActor.run {
                    postToReport = nil
                    alertMessage = "Report submitted successfully. Thank you for helping keep our community safe."
                    showSuccessAlert = true
                }
            } catch {
                print("❌ Failed to submit report: \(error.localizedDescription)")
                await MainActor.run {
                    alertMessage = "Failed to submit report: \(error.localizedDescription)"
                    showSuccessAlert = true
                }
            }
        }
    }
    
    private func convertCategory(_ category: Post.PostCategory) -> PostCategory {
        switch category {
        case .casual:
            return .casual
        case .lostFound:
            return .lostFound
        case .complaint:
            return .complaint
        case .event:
            return .event
        case .question:
            return .question
        case .arChallenge:
            return .arChallenge
        @unknown default:
            // Fallback to casual to avoid filtering out unknown categories
            return .casual
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private var reportAlertButtons: some View {
        Button("Spam") { reportPost(category: .spam) }
        Button("Harassment") { reportPost(category: .harassment) }
        Button("Inappropriate") { reportPost(category: .inappropriate) }
        Button("Misinformation") { reportPost(category: .misinformation) }
        Button("Scam") { reportPost(category: .scam) }
        Button("Threat / Violence") { reportPost(category: .threat) }
        Button("Impersonation") { reportPost(category: .impersonation) }
        Button("Hate Speech") { reportPost(category: .hates) }
        Button("Other") { reportPost(category: .other) }
        Button("Cancel", role: .cancel) {}
    }
    
    private var notificationButton: some View {
        Button {
            showNotificationList = true
        } label: {
            notificationIcon
        }
    }
    
    private var notificationIcon: some View {
        let hasUnread = !notificationManager.receivedNotifications.isEmpty || announcementCenter.unreadCount > 0
        return Image(systemName: hasUnread ? "bell.badge.fill" : "bell.fill")
            .symbolRenderingMode(hasUnread ? .palette : .monochrome)
            .foregroundStyle(
                hasUnread ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.Brand.primary),
                Color.Brand.primary
            )
    }
    
    @ViewBuilder
    private var filterMenu: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            specialOnlyFilterEnabled.toggle()
                        } label: {
                            Text("Special Only")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(specialOnlyFilterEnabled ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(specialOnlyFilterEnabled ? Color.Brand.primary : Color.Brand.surfaceMuted)
                                )
                        }
                    }
                    .frame(width: 220)
                    .padding(8)
                    .background(Color.Brand.surface.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 3)

                    Menu {
                        ForEach(categoryFilterOptions) { category in
                            Button {
                                if selectedCategories.contains(category) {
                                    selectedCategories.remove(category)
                                } else {
                                    selectedCategories.insert(category)
                                }
                            } label: {
                                HStack {
                                    Text(category.rawValue)
                                    Spacer()
                                    Image(systemName:
                                            selectedCategories.contains(category)
                                          ? "checkmark.square.fill"
                                          : "square"
                                    )
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundStyle(Color.Brand.primary)
                            .padding(10)
                            .background(Color.Brand.surface)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(radius: 4)
                    }
                }
                .padding()

                Spacer()
            }
            Spacer()
        }
    }

    private func makeSinglePostAnnotation(_ post: CampusPost) -> some View {
        PostAnnotationView(
            post: post,
            isSelected: selectedPostID == post.id,
            onTap: {
                selectedPostID = (selectedPostID == post.id) ? nil : post.id
            },
            onReport: {
                if let firebasePost = firebasePost(for: post) {
                    postToReport = firebasePost
                    showReportAlert = true
                }
            }
        )
    }
    
    private func makeClusterAnnotation(_ cluster: PostCluster) -> some View {
        PostClusterView(cluster: cluster) {
            selectedCluster = cluster
            activeSheet = .cluster
        }
    }
    
    private func makeAnnouncementAnnotation(_ ann: Announcement) -> some View {
        AnnouncementPinView(announcement: ann) {
            announcementCenter.markAsRead(ann)
            selectedAnnouncement = ann
            activeSheet = .announcement
        }
    }

    private var mapView: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            arSpawnsMapAnnotations
            postsMapAnnotations
            announcementsMapAnnotations
        }
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapUserLocationButton()
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    @MapContentBuilder
    private var arSpawnsMapAnnotations: some MapContent {
        ForEach(arSpawnDots) { dot in
            Annotation("", coordinate: dot.coordinate) {
                let markerSize = dotSize()
                ZStack {
                    Circle()
                        .fill(colorForCatchableTime(dot.catchableTime))
                        .frame(width: markerSize, height: markerSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)

                    Image(systemName: dot.symbol)
                        .font(.system(size: markerSize * 0.45, weight: .semibold))
                        .foregroundStyle(.white)
                }
                    .accessibilityLabel("\(dot.title), catchable time \(dot.catchableTime)")
            }
        }
    }

    @MapContentBuilder
    private var postsMapAnnotations: some MapContent {
        ForEach(displayClusters) { cluster in
            if cluster.count == 1 {
                let post = cluster.posts[0]
                Annotation("", coordinate: cluster.coordinate) {
                    VStack(spacing: 4) {
                        let category = convertPostCategory(post.category)
                        let visual = ContentSymbolKit.postVisual(for: category)
                        // Pin icon
                        Circle()
                            .fill(visual.color)
                            .frame(width: 29, height: 29)
                            .overlay(
                                Group {
                                    if let emoji = post.emojiPin, !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(emoji)
                                            .font(.system(size: 17))
                                    } else {
                                        Image(systemName: visual.symbol)
                                            .foregroundColor(.white)
                                            .font(.system(size: 13))
                                    }
                                }
                            )
                        
                        // Preview label
                        Text({
                            let trimmed = post.message.trimmingCharacters(in: .whitespacesAndNewlines)
                            return trimmed.isEmpty ? "Post" : String(trimmed.prefix(20))
                        }())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.Brand.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(visual.color.opacity(0.35), lineWidth: 1)
                            )
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                    .onTapGesture {
                        print("📍 Tapped post: \(post.message)")
                        selectedPost = post
                        selectedPostDocumentID = post.sourcePostID
                        activeSheet = .postDetail
                    }
                }
            } else {
                // Show cluster annotation that opens list
                Annotation("", coordinate: cluster.coordinate) {
                    ZStack {
                        PostClusterView(cluster: cluster) {
                            selectedCluster = cluster
                            activeSheet = .cluster
                        }
                    }
                }
            }
        }
    }
    
    // Helper functions for categories
    private func convertPostCategory(_ category: PostCategory) -> Post.PostCategory {
        switch category {
        case .casual:
            return .casual
        case .lostFound:
            return .lostFound
        case .complaint:
            return .complaint
        case .event:
            return .event
        case .question:
            return .question
        case .announcement:
            return .casual
        case .arChallenge:
            return .arChallenge
        }
    }
    
    private func colorForCatchableTime(_ catchableTime: Int) -> Color {
        let darkBlue = Color(red: 0.10, green: 0.20, blue: 0.65)
        switch catchableTime {
        case 1:
            return .mint
        case 2...20:
            return darkBlue
        case 21...79:
            return .green
        case 80...150:
            return .yellow
        case 151...300:
            return .red
        case 301...:
            return .gray
        default:
            // Invalid/edge fallback.
            return .gray
        }
    }

    private func dotSize() -> CGFloat {
        // Uniform AR marker size for consistency across all characters.
        16
    }

    private func startARSpawnsListener() {
        arSpawnsListener?.remove()
        arSpawnsListener = Firestore.firestore()
            .collection("ar_spawns")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("❌ Error listening ar_spawns: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.arSpawnDots = []
                    return
                }

                self.arSpawnDots = documents.flatMap { doc in
                    let data = doc.data()
                    let title = (data["title"] as? String) ?? (data["name"] as? String) ?? "AR Spawn"
                    let catchableTime = max(1, self.toInt(data["catchable_time"]) ?? 1)
                    let symbol = ContentSymbolKit.arCharacterSymbol(for: title)
                    let fixedLocations = data["fixedLocations"] as? [[String: Any]] ?? []

                    let points: [(String, Double, Double)] = fixedLocations.compactMap { location in
                        guard
                            let lat = self.toDouble(location["latitude"]),
                            let lon = self.toDouble(location["longitude"])
                        else { return nil }
                        let locationName = (location["name"] as? String) ?? "Location"
                        return (locationName, lat, lon)
                    }

                    let resolvedPoints: [(String, Double, Double)]
                    if points.isEmpty,
                       let lat = self.toDouble(data["latitude"]),
                       let lon = self.toDouble(data["longitude"]) {
                        resolvedPoints = [(title, lat, lon)]
                    } else {
                        resolvedPoints = points
                    }

                    return resolvedPoints.map { point in
                        ARSpawnMapDot(
                            id: "\(doc.documentID)@\(String(format: "%.6f", point.1)),\(String(format: "%.6f", point.2))",
                            title: point.0,
                            coordinate: CLLocationCoordinate2D(latitude: point.1, longitude: point.2),
                            catchableTime: catchableTime,
                            symbol: symbol
                        )
                    }
                }
            }
    }

    private func toDouble(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private func toInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let number = value as? NSNumber { return number.intValue }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }
    
    private func relativeTime(from date: Date) -> String {
        let mins = Int(-date.timeIntervalSinceNow / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins/60)h ago"
    }

    private func firebasePost(for campusPost: CampusPost) -> Post? {
        if let sourcePostID = campusPost.sourcePostID {
            return postByDocumentID[sourcePostID]
        }
        return postMapping[campusPost.id]
    }
    
    @MapContentBuilder
    private var announcementsMapAnnotations: some MapContent {
        ForEach(announcementCenter.announcements) { ann in
            if let coord = ann.coordinate {
                Annotation("", coordinate: coord) {
                    makeAnnouncementAnnotation(ann)
                }
            }
        }
    }

    private var mainContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.systemGray6))
                .shadow(radius: 6)
                .overlay(
                    ZStack {
                        mapView
                        if displayClusters.isEmpty {
                            VStack(spacing: 0) {
                                Text(specialOnlyFilterEnabled ? "No emoji posts nearby" : "No posts nearby")
                                    .font(.footnote)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                    .padding(.top, 92)
                                    .padding(.horizontal, 16)
                                Spacer()
                            }
                            .allowsHitTesting(false)
                        }
                        filterMenu
                    }
                )
            createPostFloatingButton
        }
        .padding()
    }

    var body: some View {
        ZStack {
            Color.Brand.appBackground
                .ignoresSafeArea()
            VStack {
                mainContent
            }
        }
        .onAppear {
            cameraPosition = .region(defaultMapRegion)
            updateClustersAndMapping()
            startARSpawnsListener()
        }
        .onDisappear {
            arSpawnsListener?.remove()
            arSpawnsListener = nil
        }
        .onReceive(postManager.$allPosts) { newValue in
            updateClustersAndMapping(posts: newValue)
        }
        .onChange(of: selectedCategories) { _, _ in
            updateClustersAndMapping()
        }
        .onChange(of: specialOnlyFilterEnabled) { _, _ in
            updateClustersAndMapping()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                notificationButton
            }
        }
        .sheet(item: $activeSheet, onDismiss: {
            if let pendingPost = pendingSelectedPost {
                DispatchQueue.main.async {
                    selectedPost = pendingPost
                    selectedPostDocumentID = pendingPost.sourcePostID
                    pendingSelectedPost = nil
                    activeSheet = .postDetail
                }
            }
        }) {
            switch $0 {
            case .announcement:
                if let ann = selectedAnnouncement {
                    SingleAnnouncementView(announcement: ann)
                } else {
                    ProgressView().padding()
                }
            case .cluster:
                if let cluster = selectedCluster {
                    ClusterPostListView(
                        posts: cluster.posts,
                        postLookup: postMapping,
                        postLookupByDocumentID: postByDocumentID,
                        onPostSelected: { selectedPost in
                            pendingSelectedPost = selectedPost
                            selectedPostDocumentID = selectedPost.sourcePostID
                            activeSheet = nil
                        },
                        onLike: { campusPost in
                            guard let postId = campusPost.sourcePostID,
                                  let userId = authManager.user?.uid else { return }
                            Task {
                                try? await postManager.likePost(postId, userId: userId)
                            }
                        },
                        onDislike: { campusPost in
                            guard let postId = campusPost.sourcePostID,
                                  let userId = authManager.user?.uid else { return }
                            Task {
                                try? await postManager.dislikePost(postId, userId: userId)
                            }
                        }
                    )
                } else {
                    ProgressView().padding()
                }
            case .postDetail:
                if let post = selectedPost {
                    PostDetailCardView(
                        post: post,
                        firebasePost: selectedPostDocumentID.flatMap { postByDocumentID[$0] } ?? firebasePost(for: post),
                        onReport: {
                            print("🚨 Report button tapped")
                            print("🔑 Looking for post ID: \(post.id)")
                            print("🔑 Available mapping keys: \(postMapping.keys.map { $0.uuidString })")
                            if let firebasePost = selectedPostDocumentID.flatMap({ postByDocumentID[$0] }) ?? firebasePost(for: post) {
                                print("✅ showReportAlert set to true")
                                print("🧾 postToReport: \(firebasePost.id ?? "nil")")
                                postToReport = firebasePost
                                showReportAlert = true
                            } else {
                                print("❌ No Firebase post found in mapping for post ID: \(post.id)")
                            }
                        },
                        onLike: {
                            guard let postId = selectedPostDocumentID ?? post.sourcePostID,
                                  let userId = authManager.user?.uid else { return }
                            Task {
                                try? await postManager.likePost(postId, userId: userId)
                            }
                        },
                        onDislike: {
                            guard let postId = selectedPostDocumentID ?? post.sourcePostID,
                                  let userId = authManager.user?.uid else { return }
                            Task {
                                try? await postManager.dislikePost(postId, userId: userId)
                            }
                        }
                    )
                    .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
                    .presentationDragIndicator(Visibility.visible)
                    .presentationBackground(Color.Brand.appBackground)
                    .alert("Report Post", isPresented: $showReportAlert) {
                        reportAlertButtons
                    } message: {
                        Text("Why are you reporting this post?")
                    }
                } else {
                    ProgressView().padding()
                }
            }
        }
        .onChange(of: activeSheet) { _, newValue in
            if newValue != .postDetail {
                selectedPostID = nil
                if newValue == nil {
                    selectedPost = nil
                    selectedPostDocumentID = nil
                }
            }
        }
        .navigationDestination(isPresented: $isPresentingCreatePost) {
            CreatePostView(isPresentedFromHome: $isPresentingCreatePost)
        }
        .alert("Report Status", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showNotificationList) {
            NotificationListView()
                .environmentObject(notificationManager)
        }
    }

    @ViewBuilder
    private var createPostFloatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    isPresentingCreatePost = true
                } label: {
                    Circle()
                        .fill(Color.Brand.primary)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.title3.bold())
                        )
                        .shadow(radius: 6)
                }
                .padding()
            }
        }
    }
}

private struct ARSpawnMapDot: Identifiable {
    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D
    let catchableTime: Int
    let symbol: String
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            chunks.append(Array(self[index..<end]))
            index += size
        }
        return chunks
    }
}
