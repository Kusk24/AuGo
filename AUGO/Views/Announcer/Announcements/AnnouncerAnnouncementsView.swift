import SwiftUI

struct AnnouncerAnnouncementsView: View {
    
    @StateObject private var viewModel = AnnouncerAnnouncementsViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            
            // FILTER BAR
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnnouncerAnnouncementFilter.allCases) { filter in
                        Button {
                            viewModel.selectedFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.subheadline.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedFilter == filter
                                    ? Color.Brand.primary
                                    : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    viewModel.selectedFilter == filter
                                    ? .white
                                    : .primary
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding()
            }
            
            // CONTENT
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
                
            } else if viewModel.filteredAnnouncements.isEmpty {
                Spacer()
                Text("No announcements")
                    .foregroundColor(.secondary)
                Spacer()
                
            } else {
                List(viewModel.filteredAnnouncements) { ann in
                    AnnouncementRow(announcement: ann)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("My Announcements")
        .onAppear {
            viewModel.startListening()
        }
    }
}
