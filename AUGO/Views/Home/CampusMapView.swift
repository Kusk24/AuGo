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
    
    @State private var showReportAlert = false
    @State private var postToReport: Post?
    @State private var selectedReportCategory: Report.ReportCategory = .spam

    // MARK: - FILTER
    @State private var selectedCategories: Set<Post.PostCategory> = Set(Post.PostCategory.allCases)

    private var filteredClusters: [PostCluster] {
        // Convert Firebase posts to clusters
        let filtered = postManager.allPosts.filter { selectedCategories.contains($0.category) }
        return createClusters(from: filtered)
    }
    
    // Convert Post array to PostCluster array
    private func createClusters(from posts: [Post]) -> [PostCluster] {
        let radius: CLLocationDistance = 50
        var remaining = posts
        var result: [PostCluster] = []

        while !remaining.isEmpty {
            let base = remaining.removeFirst()
            let baseLoc = CLLocation(latitude: base.latitude, longitude: base.longitude)
            
            // Convert Post to CampusPost for cluster
            var grouped: [CampusPost] = [CampusPost(
                author: base.userId,
                message: base.content,
                coordinate: base.coordinate,
                category: convertCategory(base.category),
                createdAt: base.date
            )]

            remaining.removeAll { post in
                let loc = CLLocation(latitude: post.latitude, longitude: post.longitude)
                if baseLoc.distance(from: loc) < radius {
                    grouped.append(CampusPost(
                        author: post.userId,
                        message: post.content,
                        coordinate: post.coordinate,
                        category: convertCategory(post.category),
                        createdAt: post.date
                    ))
                    return true
                }
                return false
            }

            result.append(PostCluster(coordinate: grouped[0].coordinate, posts: grouped))
        }

        return result
    }
    
    // Helper to convert Post.PostCategory to PostCategory
    private func convertCategory(_ category: Post.PostCategory) -> PostCategory {
        switch category {
        case .casual:
            return .casual
        case .event, .question, .announcement, .arChallenge:
            return .casual  // Map other categories to casual for now
        }
    }
    
    // MARK: - Extracted subviews to help the compiler
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

    @ViewBuilder
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            // Posts & clusters
            ForEach(filteredClusters) { cluster in
                let coordinate: CLLocationCoordinate2D = cluster.coordinate
                Annotation("", coordinate: coordinate) {
                    if cluster.count == 1 {
                        let post: CampusPost = cluster.posts[0]
                        PostAnnotationView(
                            post: post,
                            isSelected: viewModel.selectedPostID == post.id
                        ) {
                            viewModel.toggleSelected(post)
                        }
                    } else {
                        PostClusterView(cluster: cluster) {
                            selectedCluster = cluster
                            showClusterSheet = true
                        }
                    }
                }
            }

            // Announcements
            ForEach(announcementCenter.announcements) { ann in
                if let coord = ann.coordinate {
                    let coordinate: CLLocationCoordinate2D = coord
                    Annotation("", coordinate: coordinate) {
                        AnnouncementPinView(announcement: ann) {
                            announcementCenter.markAsRead(ann)
                            selectedAnnouncement = ann
                            showSingleAnnouncement = true
                        }
                    }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapUserLocationButton()
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.systemGray6))
                        .shadow(radius: 6)
                        .overlay(
                            ZStack {
                                mapContent
                                filterMenu
                            }
                        )

                    // MARK: - CREATE POST BUTTON
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
                .padding()
            }
        }
        .onAppear {
            cameraPosition = .region(viewModel.campusRegion)
            postManager.fetchAllPosts()  // Fetch Firebase posts on appear
        }
        .onChange(of: postManager.allPosts.count) { oldValue, newValue in
            // Trigger a refresh by touching state if needed
            // No-op: computed properties will recompute automatically
        }
        .alert("Report Post", isPresented: $showReportAlert) {
            Button("Spam") {
                if let post = postToReport, let userId = authManager.user?.uid {
                    Task {
                        try? await postManager.reportPost(post.id ?? "", category: .spam, reportedBy: userId)
                    }
                }
            }
            Button("Harassment") {
                if let post = postToReport, let userId = authManager.user?.uid {
                    Task {
                        try? await postManager.reportPost(post.id ?? "", category: .harassment, reportedBy: userId)
                    }
                }
            }
            Button("Inappropriate") {
                if let post = postToReport, let userId = authManager.user?.uid {
                    Task {
                        try? await postManager.reportPost(post.id ?? "", category: .inappropriate, reportedBy: userId)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Why are you reporting this post?")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    announcementCenter.markAllAsRead()
                    showAnnouncement = true
                } label: {
                    Image(systemName:
                        announcementCenter.unreadCount > 0
                        ? "bell.badge.fill"
                        : "bell.fill"
                    )
                    .symbolRenderingMode(
                        announcementCenter.unreadCount > 0
                        ? .palette
                        : .monochrome
                    )
                    .foregroundStyle(
                        announcementCenter.unreadCount > 0
                        ? AnyShapeStyle(Color.red)           // dot
                        : AnyShapeStyle(Color.Brand.primary),// bell (read)
                        Color.Brand.primary                  // bell (unread)
                    )
                }
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
}

