import SwiftUI
import FirebaseAuth
import CoreLocation
import UIKit
import FirebaseCore

struct PostDetailCardView: View {
    let post: CampusPost
    let firebasePost: Post?
    let onReport: () -> Void
    let onLike: (() -> Void)?
    let onDislike: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var userReaction: String? = nil
    @State private var lastKnownLikeCount: Int = 0
    @State private var lastKnownDislikeCount: Int = 0
    
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
        case .announcement:
            return .gray
        case .arChallenge:
            return .green
        }
    }
    
    private var categoryIcon: String {
        switch post.category {
        case .casual:
            return "bolt.heart.fill"
        case .lostFound:
            return "mappin.and.ellipse"
        case .complaint:
            return "exclamationmark.triangle.fill"
        case .event:
            return "calendar"
        case .question:
            return "questionmark.circle.fill"
        case .announcement:
            return "megaphone.fill"
        case .arChallenge:
            return "arkit"
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

    private var photoPaths: [String] {
        firebasePost?.photoPaths ?? []
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Text("Post")
                            .font(.headline)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Circle()
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
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

                    if !photoPaths.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Photos")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(photoPaths, id: \.self) { path in
                                        if let url = storageDownloadURL(for: path) {
                                            CachedRemoteImage(url: url, cacheKey: url.absoluteString) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color(UIColor.systemGray5))
                                                    Image(systemName: "photo")
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .frame(width: 220, height: 220)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
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
                        
                        // Engagement stats (always visible; shows live counts when available)
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
                                        Text("\(firebasePost?.likeCount ?? lastKnownLikeCount)")
                                    }

                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down")
                                        Text("\(firebasePost?.dislikeCount ?? lastKnownDislikeCount)")
                                    }
                                }
                                .font(.subheadline)
                            }

                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Like/Dislike buttons (always visible; counts update when firebasePost updates)
                    HStack(spacing: 12) {
                        Button(action: {
                            // Optimistically update local reaction and counts
                            let previous = userReaction
                            if previous == "like" {
                                // Removing like
                                userReaction = nil
                                lastKnownLikeCount = max(0, lastKnownLikeCount - 1)
                            } else if previous == "dislike" {
                                // Switching from dislike to like
                                userReaction = "like"
                                lastKnownDislikeCount = max(0, lastKnownDislikeCount - 1)
                                lastKnownLikeCount += 1
                            } else {
                                // Adding like
                                userReaction = "like"
                                lastKnownLikeCount += 1
                            }
                            onLike?()
                        }) {
                            HStack {
                                Image(systemName: userReaction == "like" ? "hand.thumbsup.fill" : "hand.thumbsup")
                                Text("Like")
                                Text("(\(firebasePost?.likeCount ?? lastKnownLikeCount))")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(userReaction == "like" ? Color.green : Color.green.opacity(0.1))
                            .foregroundColor(userReaction == "like" ? .white : .green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: {
                            // Optimistically update local reaction and counts
                            let previous = userReaction
                            if previous == "dislike" {
                                // Removing dislike
                                userReaction = nil
                                lastKnownDislikeCount = max(0, lastKnownDislikeCount - 1)
                            } else if previous == "like" {
                                // Switching from like to dislike
                                userReaction = "dislike"
                                lastKnownLikeCount = max(0, lastKnownLikeCount - 1)
                                lastKnownDislikeCount += 1
                            } else {
                                // Adding dislike
                                userReaction = "dislike"
                                lastKnownDislikeCount += 1
                            }
                            onDislike?()
                        }) {
                            HStack {
                                Image(systemName: userReaction == "dislike" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                Text("Dislike")
                                Text("(\(firebasePost?.dislikeCount ?? lastKnownDislikeCount))")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(userReaction == "dislike" ? Color.orange : Color.orange.opacity(0.1))
                            .foregroundColor(userReaction == "dislike" ? .white : .orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            openInMaps()
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
            .onAppear {
                // Seed last known counts so Engagement stays visible even if firebasePost is briefly nil
                if let fbPost = firebasePost {
                    lastKnownLikeCount = fbPost.likeCount
                    lastKnownDislikeCount = fbPost.dislikeCount
                }
                Task {
                    await loadUserReaction()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: firebasePost?.likeCount) { _, newValue in
                if let newValue = newValue { lastKnownLikeCount = newValue }
            }
            .onChange(of: firebasePost?.dislikeCount) { _, newValue in
                if let newValue = newValue { lastKnownDislikeCount = newValue }
            }
        }
    }
    
    private func loadUserReaction() async {
        guard let fbPost = firebasePost,
              let postId = fbPost.id,
              let userId = authManager.user?.uid else { return }
        
        do {
            let reaction = try await postManager.getUserReaction(postId: postId, userId: userId)
            await MainActor.run {
                userReaction = reaction
            }
        } catch {
            // Silently handle permission errors - security rules may not be set yet
            // User will still see buttons, just won't see saved reaction state initially
        }
    }
    
    private func openInMaps() {
        let latitude = post.coordinate.latitude
        let longitude = post.coordinate.longitude
        let query = post.message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Pinned%20Location"
        
        guard let mapsURL = URL(string: "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(query)") else {
            return
        }
        
        UIApplication.shared.open(mapsURL)
    }

    private func storageDownloadURL(for assetPath: String) -> URL? {
        guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let escapedPath = assetPath.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
    }
}
