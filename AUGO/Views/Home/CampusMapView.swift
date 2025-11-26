import SwiftUI

struct CampusMapView: View {
    @Binding var showAnnouncement: Bool
    @State private var isPresentingCreatePost = false

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Map card + + button
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(UIColor.systemGray6))
                        .overlay(
                            Image("CampusMap")
                                .resizable()
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                        )
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                        // 👉 tap map to show sheet
                        .onTapGesture {
                            showAnnouncement = true
                        }

                    // Hamburger menu
                    VStack {
                        HStack {
                            Button {} label: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white)
                                    .shadow(radius: 2)
                                    .frame(width: 40, height: 32)
                                    .overlay(
                                        Image(systemName: "line.3.horizontal")
                                            .foregroundColor(.black)
                                    )
                            }
                            Spacer()
                        }
                        .padding(.top, 16)
                        .padding(.leading, 16)

                        Spacer()
                    }

                    // Floating +
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                isPresentingCreatePost = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.Brand.primary)
                                        .frame(width: 56, height: 56)
                                        .shadow(color: .black.opacity(0.25),
                                                radius: 8, y: 4)

                                    Image(systemName: "plus")
                                        .foregroundColor(.white)
                                        .font(.title3.bold())
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Text("200")
                        .font(.subheadline.bold())

                    ZStack {
                        Circle()
                            .fill(Color.Brand.coin)
                            .frame(width: 22, height: 22)
                        Text("£")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }

                Button {} label: {
                    Image(systemName: "bell.fill")
                        .foregroundColor(Color.Brand.primary)
                }
            }
        }
        .navigationDestination(isPresented: $isPresentingCreatePost) {
            CreatePostView(isPresentedFromHome: $isPresentingCreatePost)
        }
    }
}

// MARK: - Announcement overlay (same file)

struct AnnouncementOverlay: View {
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            // Dimmed background – blocks taps everywhere
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowing = false
                }

            // Center card
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        isShowing = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .padding(8)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Online Pre-registration Period for 2/2025")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text("""
Dear VMES students,

• 60x – 65x students (All faculties) on Tuesday, October 21st, 2025 between 11:45 – 12:30.
• 66x students (All faculties) on Tuesday, October 21st, 2025 between 14:45 – 15:30.

If 60–66x students miss their recommended periods, you have another chance to pre-register on Tuesday, October 21st, 2025 between 15:30 – 16:30.

• 67x students (All faculties) on Wednesday, October 22nd, 2025 between 10:30 – 11:15.
• 68x students (All faculties) on Wednesday, October 22nd, 2025 between 13:30 – 14:15.

Sincerely yours,
Allapon Hutasin
Assistant Dean for Academic Affairs
Vincent Mary School of Engineering, Science and Technology
""")
                            .font(.system(size: 13))
                            .foregroundColor(.black)
                    }
                    .padding()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 120)
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut, value: isShowing)
    }
}
