import SwiftUI
internal import MapKit
import FirebaseAuth

struct CampusMapView: View {
    @Binding var showAnnouncement: Bool

    @EnvironmentObject var viewModel: CampusMapViewModel
    @EnvironmentObject var announcementCenter: AnnouncementCenter
    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var cameraPosition: MapCameraPosition = .automatic

    @State private var selectedAnnouncement: Announcement?
    @State private var showSingleAnnouncement = false

    @State private var isPresentingCreatePost = false

    @State private var selectedCluster: PostCluster?
    @State private var showClusterSheet = false
    
    @State private var selectedPostID: UUID? = nil
    @State private var postMapping: [UUID: Post] = [:]
    
    @State private var showReportAlert = false
    @State private var postToReport: Post?    
    @State private var showPostDetail = false
    @State private var selectedPost: CampusPost?
    @State private var showSuccessAlert = false
    @State private var alertMessage = ""
    @State private var showNotificationList = false
    // MARK: - FILTER
    @State private var selectedCategories: Set<Post.PostCategory> = Set(Post.PostCategory.allCases)
    @State private var displayClusters: [PostCluster] = []
    
    private func updateClustersAndMapping(posts: [Post]? = nil) {
        let postsToUse = posts ?? postManager.allPosts
        let filtered = postsToUse.filter { selectedCategories.contains($0.category) }
        print("🎯 Filtering: \(postsToUse.count) total posts -> \(filtered.count) after category filter")

        let (clusters, mapping) = createClusters(from: filtered)
        print("📌 Created \(clusters.count) clusters from \(filtered.count) posts")

        displayClusters = clusters
        postMapping = mapping
        print("🗺️ Updated postMapping with \(mapping.count) entries")
        print("🔑 Mapping keys: \(mapping.keys.map { $0.uuidString })")
    }
    
    private func createClusters(from posts: [Post]) -> ([PostCluster], [UUID: Post]) {
        print("🔨 createClusters called with \(posts.count) posts")
        
        let radius: CLLocationDistance = 50
        var remaining = posts
        var result: [PostCluster] = []
        var newMapping: [UUID: Post] = [:]

        while !remaining.isEmpty {
            let base = remaining.removeFirst()
            let baseLoc = CLLocation(latitude: base.latitude, longitude: base.longitude)
            
            let campusPost = CampusPost(
                author: base.userId,
                message: base.content,
                coordinate: base.coordinate,
                category: convertCategory(base.category),
                createdAt: base.date
            )
            
            newMapping[campusPost.id] = base
            var grouped: [CampusPost] = [campusPost]

            remaining.removeAll { post in
                let loc = CLLocation(latitude: post.latitude, longitude: post.longitude)
                if baseLoc.distance(from: loc) < radius {
                    let cp = CampusPost(
                        author: post.userId,
                        message: post.content,
                        coordinate: post.coordinate,
                        category: convertCategory(post.category),
                        createdAt: post.date
                    )
                    newMapping[cp.id] = post
                    grouped.append(cp)
                    return true
                }
                return false
            }

            result.append(PostCluster(coordinate: grouped[0].coordinate, posts: grouped))
        }

        print("✅ Created \(result.count) clusters with total of \(newMapping.count) posts")
        return (result, newMapping)
    }
    
    // MARK: - Helper Methods
    
    private func handlePostsChange(_ newValue: [Post]) {
        print("📍 Posts changed: \(newValue.count) posts available")
        if newValue.isEmpty {
            print("⚠️ WARNING: No posts in postManager.allPosts")
        } else {
            print("✅ Posts available:")
            for post in newValue.prefix(3) {
                print("   - \(post.content) at (\(post.latitude), \(post.longitude))")
            }
        }
    }
    
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
        case .event:
            return .event
        case .question:
            return .question
        case .announcement:
            return .announcement
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
        Button("Cancel", role: .cancel) {}
    }
    
    private var notificationButton: some View {
        Button {
            showNotificationList = true
        } label: {
            notificationIcon
        }
        .sheet(isPresented: $showNotificationList) {
            NotificationListView()
        }
    }
    
    private var notificationIcon: some View {
        let hasUnread = announcementCenter.unreadCount > 0
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
                Menu {
                    ForEach(Post.PostCategory.allCases) { category in
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
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
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
                if let firebasePost = postMapping[post.id] {
                    postToReport = firebasePost
                    showReportAlert = true
                }
            }
        )
    }
    
    private func makeClusterAnnotation(_ cluster: PostCluster) -> some View {
        PostClusterView(cluster: cluster) {
            selectedCluster = cluster
            showClusterSheet = true
        }
    }
    
    private func makeAnnouncementAnnotation(_ ann: Announcement) -> some View {
        AnnouncementPinView(announcement: ann) {
            announcementCenter.markAsRead(ann)
            selectedAnnouncement = ann
            showSingleAnnouncement = true
        }
    }

    private var mapView: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
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
    private var postsMapAnnotations: some MapContent {
        ForEach(displayClusters) { cluster in
            if cluster.count == 1 {
                let post = cluster.posts[0]
                Annotation("", coordinate: cluster.coordinate) {
                    VStack(spacing: 4) {
                        // Pin icon
                        Circle()
                            .fill(colorForCategory(convertPostCategory(post.category)))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                            )
                        
                        // Preview label
                        Text(String(post.message.prefix(20)))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                    .onTapGesture {
                        print("📍 Tapped post: \(post.message)")
                        selectedPost = post
                        showPostDetail = true
                    }
                }
            } else {
                // Show cluster annotation that opens list
                Annotation("", coordinate: cluster.coordinate) {
                    ZStack {
                        PostClusterView(cluster: cluster) {
                            selectedCluster = cluster
                            showClusterSheet = true
                        }
                    }
                    .onTapGesture {
                        selectedCluster = cluster
                        showClusterSheet = true
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
        case .event:
            return .event
        case .question:
            return .question
        case .announcement:
            return .announcement
        case .arChallenge:
            return .arChallenge
        case .lostFound:
            // Fallback to casual for unsupported backend category
            return .casual
        case .complaint:
            // Fallback to casual for unsupported backend category
            return .casual
        }
    }
    
    private func colorForCategory(_ category: Post.PostCategory) -> Color {
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
    
    private func relativeTime(from date: Date) -> String {
        let mins = Int(-date.timeIntervalSinceNow / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins/60)h ago"
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
                            VStack {
                                Text("No posts nearby")
                                    .font(.footnote)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                    .padding()
                                Spacer()
                            }
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
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()
            VStack {
                mainContent
            }
        }
        .onAppear {
            cameraPosition = .region(viewModel.campusRegion)
            print("🗺️ CampusMapView appeared")
            print("📊 Current state: \(postManager.allPosts.count) posts in PostManager")
            print("🎯 Selected categories: \(selectedCategories.map { $0.rawValue })")
            updateClustersAndMapping()
        }
        .onReceive(postManager.$allPosts) { newValue in
            print("📬 Received posts update: \(newValue.count) posts")
            handlePostsChange(newValue)
            updateClustersAndMapping(posts: newValue)
        }
        .onChange(of: selectedCategories) { _, newValue in
            print("🔍 Filter changed: \(newValue.count) categories selected")
            updateClustersAndMapping()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                notificationButton
            }
        }
        .sheet(isPresented: $showSingleAnnouncement) {
            if let ann = selectedAnnouncement {
                SingleAnnouncementView(announcement: ann)
            }
        }
        .sheet(isPresented: $showClusterSheet) {
            if let cluster = selectedCluster {
                ClusterPostListView(posts: cluster.posts) { selectedPost in
                    self.selectedPost = selectedPost
                    showPostDetail = true
                }
            }
        }
        .sheet(isPresented: $showPostDetail, onDismiss: {
            // Clear selected post when sheet is dismissed
            selectedPost = nil
            selectedPostID = nil
        }) {
            if let post = selectedPost {
                PostDetailCardView(
                    post: post,
                    firebasePost: postMapping[post.id],
                    onReport: {
                        print("🚨 Report button tapped")
                        print("🔑 Looking for post ID: \(post.id)")
                        print("🔑 Available mapping keys: \(postMapping.keys.map { $0.uuidString })")
                        if let firebasePost = postMapping[post.id] {
                            print("✅ showReportAlert set to true")
                            print("🧾 postToReport: \(firebasePost.id ?? "nil")")
                            postToReport = firebasePost
                            showReportAlert = true
                        } else {
                            print("❌ No Firebase post found in mapping for post ID: \(post.id)")
                        }
                    },
                    onLike: {
                        guard let firebasePost = postMapping[post.id], 
                              let postId = firebasePost.id,
                              let userId = authManager.user?.uid else { return }
                        Task {
                            try? await postManager.likePost(postId, userId: userId)
                        }
                    },
                    onDislike: {
                        guard let firebasePost = postMapping[post.id], 
                              let postId = firebasePost.id,
                              let userId = authManager.user?.uid else { return }
                        Task {
                            try? await postManager.dislikePost(postId, userId: userId)
                        }
                    }
                )
                .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
                .presentationDragIndicator(Visibility.visible)
                .alert("Report Post", isPresented: $showReportAlert) {
                    reportAlertButtons
                } message: {
                    Text("Why are you reporting this post?")
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

