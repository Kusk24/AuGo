import SwiftUI
internal import MapKit

struct PostDetailCardView: View {
    let post: CampusPost
    let firebasePost: Post?
    let onReport: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var categoryColor: Color {
        switch post.category {
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
        case .lostFound:
            return .red
        case .complaint:
            return .yellow
        }
    }
    
    private var categoryIcon: String {
        switch post.category {
        case .casual:
            return "bolt.heart.fill"
        case .event:
            return "calendar"
        case .question:
            return "questionmark.circle.fill"
        case .announcement:
            return "megaphone.fill"
        case .arChallenge:
            return "arkit"
        case .lostFound:
            return "location.fill.viewfinder"
        case .complaint:
            return "exclamationmark.bubble.fill"
        }
    }
    
    private var relativeTime: String {
        let mins = Int(-post.createdAt.timeIntervalSinceNow / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours/24)d ago"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header with category badge
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: categoryIcon)
                                .foregroundColor(categoryColor)
                            
                            Text(post.category.rawValue)
                                .font(.headline)
                                .foregroundColor(categoryColor)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(categoryColor.opacity(0.15))
                        .clipShape(Capsule())
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Post message (main content)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(post.message)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Post details
                    VStack(spacing: 16) {
                        // Author
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                                .foregroundColor(categoryColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Posted by")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(post.author)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                        }
                        
                        // Time
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.title3)
                                .foregroundColor(categoryColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Posted")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(relativeTime)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                        }
                        
                        // Location coordinates
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(categoryColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(String(format: "%.5f, %.5f", post.coordinate.latitude, post.coordinate.longitude))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Engagement stats if available
                        if let fbPost = firebasePost {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .font(.title3)
                                    .foregroundColor(categoryColor)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Engagement")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 16) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up")
                                            Text("\(fbPost.likeCount)")
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down")
                                            Text("\(fbPost.dislikeCount)")
                                        }
                                    }
                                    .font(.subheadline)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Open in Apple Maps
                            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: post.coordinate))
                            mapItem.name = post.message
                            mapItem.openInMaps(launchOptions: nil)
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Open in Maps")
                                Spacer()
                                Image(systemName: "arrow.up.forward.square")
                            }
                            .font(.body)
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button(action: {
                            onReport()
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Report Post")
                                Spacer()
                            }
                            .font(.body)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
            }
        }
    }
}
