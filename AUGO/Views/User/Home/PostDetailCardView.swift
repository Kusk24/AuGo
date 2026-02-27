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
    @State private var isReactionSubmitting = false
    
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

    private var postTitle: String {
        let trimmed = post.author.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "User" : trimmed
        let suffix = name.lowercased().hasSuffix("s") ? "'" : "'s"
        return "\(name)\(suffix) Post"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Text(postTitle)
                        .font(.title3.weight(.bold))

                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Circle()
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                HStack(spacing: 10) {
                    Label(post.category.rawValue, systemImage: categoryIcon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(categoryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(categoryColor.opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    Text(post.author)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)

                if !post.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(post.message)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.Brand.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                }

                if !photoPaths.isEmpty {
                    TabView {
                        ForEach(photoPaths, id: \.self) { path in
                            if let url = storageDownloadURL(for: path) {
                                CachedRemoteImage(url: url, cacheKey: url.absoluteString) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(UIColor.systemGray5))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.secondary)
                                        )
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .frame(height: 260)
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(relativeTime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.5f, %.5f", post.coordinate.latitude, post.coordinate.longitude))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 16) {
                        Label("\(firebasePost?.likeCount ?? lastKnownLikeCount)", systemImage: "arrow.up")
                            .foregroundColor(.secondary)
                        Label("\(firebasePost?.dislikeCount ?? lastKnownDislikeCount)", systemImage: "arrow.down")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.Brand.surfaceMuted)
                )
                .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    Button(action: handleLikeTap) {
                        Label("Like (\(firebasePost?.likeCount ?? lastKnownLikeCount))", systemImage: userReaction == "like" ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(userReaction == "like" ? Color.green : Color.green.opacity(0.12))
                            .foregroundColor(userReaction == "like" ? .white : .green)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(isReactionSubmitting)

                    Button(action: handleDislikeTap) {
                        Label("Dislike (\(firebasePost?.dislikeCount ?? lastKnownDislikeCount))", systemImage: userReaction == "dislike" ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(userReaction == "dislike" ? Color.orange : Color.orange.opacity(0.12))
                            .foregroundColor(userReaction == "dislike" ? .white : .orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(isReactionSubmitting)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    Button(action: openInMaps) {
                        Label("Open in Maps", systemImage: "map")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button(action: onReport) {
                        Label("Report", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
            .padding(.top, 4)
        }
        .onAppear {
            if let fbPost = firebasePost {
                lastKnownLikeCount = fbPost.likeCount
                lastKnownDislikeCount = fbPost.dislikeCount
            }
            Task { await loadUserReaction() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: firebasePost?.likeCount) { _, newValue in
            if let newValue = newValue { lastKnownLikeCount = newValue }
        }
        .onChange(of: firebasePost?.dislikeCount) { _, newValue in
            if let newValue = newValue { lastKnownDislikeCount = newValue }
        }
    }

    private func handleLikeTap() {
        guard !isReactionSubmitting else { return }
        isReactionSubmitting = true
        let previous = userReaction
        if previous == "like" {
            userReaction = nil
            lastKnownLikeCount = max(0, lastKnownLikeCount - 1)
        } else if previous == "dislike" {
            userReaction = "like"
            lastKnownDislikeCount = max(0, lastKnownDislikeCount - 1)
            lastKnownLikeCount += 1
        } else {
            userReaction = "like"
            lastKnownLikeCount += 1
        }
        onLike?()
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run { isReactionSubmitting = false }
        }
    }

    private func handleDislikeTap() {
        guard !isReactionSubmitting else { return }
        isReactionSubmitting = true
        let previous = userReaction
        if previous == "dislike" {
            userReaction = nil
            lastKnownDislikeCount = max(0, lastKnownDislikeCount - 1)
        } else if previous == "like" {
            userReaction = "dislike"
            lastKnownLikeCount = max(0, lastKnownLikeCount - 1)
            lastKnownDislikeCount += 1
        } else {
            userReaction = "dislike"
            lastKnownDislikeCount += 1
        }
        onDislike?()
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run { isReactionSubmitting = false }
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
