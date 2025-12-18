import SwiftUI
import MapKit

struct CampusMapView: View {
    @Binding var showAnnouncement: Bool

    @EnvironmentObject var viewModel: CampusMapViewModel
    @EnvironmentObject var announcementCenter: AnnouncementCenter

    @State private var cameraPosition: MapCameraPosition = .automatic

    @State private var selectedAnnouncement: Announcement?
    @State private var showSingleAnnouncement = false

    @State private var isPresentingCreatePost = false

    @State private var selectedCluster: PostCluster?
    @State private var showClusterSheet = false

    // MARK: - FILTER
    @State private var selectedCategories: Set<PostCategory> = Set(PostCategory.allCases)

    private var filteredClusters: [PostCluster] {
        viewModel.clusters.compactMap { cluster in
            let posts = cluster.posts.filter {
                selectedCategories.contains($0.category)
            }
            guard !posts.isEmpty else { return nil }
            return PostCluster(coordinate: cluster.coordinate, posts: posts)
        }
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

                                // MARK: - MAP
                                Map(position: $cameraPosition) {

                                    UserAnnotation()

                                    ForEach(filteredClusters) { cluster in
                                        Annotation("", coordinate: cluster.coordinate) {
                                            if cluster.count == 1 {
                                                let post = cluster.posts[0]
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

                                    ForEach(announcementCenter.announcements) { ann in
                                        if let coord = ann.coordinate {
                                            Annotation("", coordinate: coord) {
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

                                // MARK: - FILTER MENU (INLINE)
                                VStack {
                                    HStack {
                                        Menu {
                                            ForEach(PostCategory.allCases) { category in
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
            viewModel.rebuildClusters()
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
