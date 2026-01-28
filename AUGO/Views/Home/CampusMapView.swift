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

    // MARK: - FILTER
    @State private var selectedCategories: Set<Post.PostCategory> = Set(Post.PostCategory.allCases)

    private var filteredClusters: [PostCluster] {
        let filtered = postManager.allPosts.filter { selectedCategories.contains($0.category) }
        print("🎯 Filtering: \(postManager.allPosts.count) total posts -> \(filtered.count) after category filter")
        let clusters = createClusters(from: filtered)
        print("📌 Created \(clusters.count) clusters from \(filtered.count) posts")
        return clusters
    }
    
    private func createClusters(from posts: [Post]) -> [PostCluster] {
        print("🔨 createClusters called with \(posts.count) posts")
        
        let radius: CLLocationDistance = 50
        var remaining = posts
        var result: [PostCluster] = []
        var newMapping: [UUID: Post] = [:]

        while !remaining.isEmpty {
            let base = remaining.removeFirst()
            let baseLoc = CLLocation(latitude: base.latitude, longitude: base.longitude)
            
            // TODO: Use post owner's nickname here if available, instead of userId. You may need to fetch/display actual user info.
            // To supply the correct author field here, consider fetching nickname from user profile or caching it.
            let campusPost = CampusPost(
                author: base.userId /* TODO: Replace with nickname if available */,
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
                    // TODO: Use post owner's nickname here if available, instead of userId. You may need to fetch/display actual user info.
                    // To supply the correct author field here, consider fetching nickname from user profile or caching it.
                    let cp = CampusPost(
                        author: post.userId /* TODO: Replace with nickname if available */,
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
        
        DispatchQueue.main.async {
            postMapping = newMapping
        }

        print("✅ Created \(result.count) clusters with total of \(newMapping.count) posts")
        return result
    }
    
    // MARK: - Helper Methods
    
    private func handlePostsChange(_ newValue: [Post]) {
        print("📍 Posts changed: \(newValue.count) posts available")
        print("📍 Filtered clusters: \(filteredClusters.count)")
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
              let userId = authManager.user?.uid else { return }
        Task {
            try? await postManager.reportPost(post.id ?? "", category: category, reportedBy: userId)
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
            announcementCenter.markAllAsRead()
            showAnnouncement = true
        } label: {
            notificationIcon
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
        ForEach(filteredClusters) { cluster in
            Annotation("", coordinate: cluster.coordinate) {
                if cluster.count == 1 {
                    makeSinglePostAnnotation(cluster.posts[0])
                } else {
                    makeClusterAnnotation(cluster)
                }
            }
        }
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
        }
        .onReceive(postManager.$allPosts) { newValue in
            print("📬 Received posts update: \(newValue.count) posts")
            handlePostsChange(newValue)
        }
        .onChange(of: selectedCategories) { _, newValue in
            print("🔍 Filter changed: \(newValue.count) categories selected")
        }
        .alert("Report Post", isPresented: $showReportAlert) {
            reportAlertButtons
        } message: {
            Text("Why are you reporting this post?")
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
                ClusterPostListView(posts: cluster.posts)
            }
        }
        .navigationDestination(isPresented: $isPresentingCreatePost) {
            CreatePostView(isPresentedFromHome: $isPresentingCreatePost)
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

