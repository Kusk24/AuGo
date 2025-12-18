import SwiftUI
import MapKit

struct CreatePostView: View {
    @Binding var isPresentedFromHome: Bool
    
    @EnvironmentObject var postManager: PostManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var viewModel: CampusMapViewModel

    @State private var message: String = ""
    @State private var selectedCategory: Post.Category? = nil

    private var canPost: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && selectedCategory != nil
    }

    private var userAvatar: String {
        if let nickname = authManager.userProfile?.nickname {
            return String(nickname.prefix(1)).uppercased()
        }
        return "U"
    }

    private var userName: String {
        authManager.userProfile?.nickname ?? "User"
    }

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.Brand.primary.opacity(0.2))
                                .frame(width: 36, height: 36)

                            Text(userAvatar)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.Brand.primary)
                        }

                        Text(userName)
                            .font(.subheadline.bold())

                        Spacer()

                        Menu {
                            ForEach(Post.Category.allCases) { category in
                                Button(category.rawValue) {
                                    selectedCategory = category
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(selectedCategory?.rawValue ?? "Category")
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.Brand.primary.opacity(0.15))
                            .foregroundColor(Color.Brand.primary)
                            .clipShape(Capsule())
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray6))

                        TextEditor(text: $message)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)

                        if message.isEmpty {
                            Text("Share something with the campus.")
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
                )
                .padding(.horizontal)

                NavigationLink {
                    CreatePostMapView(
                        isPresentedFromHome: $isPresentedFromHome,
                        content: message,
                        category: selectedCategory ?? .casual
                    )
                } label: {
                    Text("Choose Location on Map")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(canPost ? Color.Brand.primary : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!canPost)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Create Post")
        .navigationBarTitleDisplayMode(.inline)
    }
}
