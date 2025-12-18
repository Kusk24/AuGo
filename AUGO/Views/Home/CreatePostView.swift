import SwiftUI

struct CreatePostView: View {
    @Binding var isPresentedFromHome: Bool

    @State private var message: String = ""
    @State private var selectedCategory: PostCategory? = nil

    @State private var goToMap = false
    @State private var pendingMessage: String = ""
    @State private var pendingCategory: PostCategory = .casual

    private var canPost: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && selectedCategory != nil
    }

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            VStack(spacing: 12) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image("Richard")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())

                        Text("Richard")
                            .font(.subheadline.bold())

                        Spacer()

                        Menu {
                            ForEach(PostCategory.allCases) { category in
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

                Button {
                    guard let selectedCategory else { return }
                    pendingMessage = message
                    pendingCategory = selectedCategory
                    goToMap = true
                } label: {
                    Text("Choose location")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
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
        .navigationDestination(isPresented: $goToMap) {
            CreatePostMapView(
                isPresentedFromHome: $isPresentedFromHome,
                message: pendingMessage,
                category: pendingCategory
            )
        }
    }
}
