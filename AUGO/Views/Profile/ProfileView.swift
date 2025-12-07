import SwiftUI

struct ProfileView: View {
    
    @EnvironmentObject var authManager: AuthenticationManager

    // dummy data for now
    private let name       = "Richard"
    private let studentID  = "7041951"
    private let totalPoints = 1700
    private let rank        = 3

    @State private var notificationsOn = true
    @State private var showLogoutAlert = false

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Avatar + name
                    VStack(spacing: 12) {
                        Image("Richard")            // reuse the same asset as CreatePost
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())

                        Text(name)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.primary)

                        Text("Student ID: \(studentID)")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // MARK: Stats cards
                    HStack(spacing: 16) {
                        ProfileStatCard(
                            title: "Total Points",
                            value: "\(totalPoints)"
                        )

                        ProfileStatCard(
                            title: "Rank",
                            value: "#\(rank)"
                        )
                    }
                    .padding(.horizontal, 16)

                    // MARK: Today Post
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Today Post")

                        TodayPostCard()
                    }
                    .padding(.horizontal, 16)

                    // MARK: Captured Characters
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Captured Characters")

                        Text("Your collection of characters")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        CapturedCharacterCard()
                    }
                    .padding(.horizontal, 16)

                    // MARK: Settings
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Settings")

                        Text("Manage your account preferences here.")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        HStack {
                            Text("Notification Preferences")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()

                            Toggle("", isOn: $notificationsOn)
                                .labelsHidden()
                                .tint(Color.Brand.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray6))
                        )
                    }
                    .padding(.horizontal, 16)

                    // MARK: Logout button
                    Button {
                        showLogoutAlert = true
                    } label: {
                        Text("Logout")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        // navigation title is already set in RootTabView:
        // .navigationTitle("Profile")
        // .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Reusable bits

private struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color.Brand.primary)
    }
}

private struct ProfileStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.9))

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.Brand.coin)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TodayPostCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.Brand.primary.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "bolt.heart")
                            .foregroundColor(Color.Brand.primary)
                            .font(.system(size: 14, weight: .semibold))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Casual")
                        .font(.caption)
                        .foregroundColor(.primary)

                    Text("Posted 4 hours ago")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.8))
                    .font(.system(size: 14, weight: .semibold))
            }

            Text("We’re having a multicultural food event. All come grab some food! 🍱🍜🌯✨")
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                    Text("115")
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                    Text("2")
                }
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
        )
    }
}

import SwiftUI

private struct CapturedCharacterCard: View {
    var body: some View {
        VStack(spacing: 0) {

            // TOP
            ZStack {
                Color(UIColor.systemGray6)

                Image("Foxy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            }
            .frame(height: 130)
            .clipShape(
                RoundedCorner(radius: 14, corners: [.topLeft, .topRight])
            )

            // BOTTOM
            ZStack {
                Color(.white)

                Text("Fox · 75 coins")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .frame(height: 40)
            .clipShape(
                RoundedCorner(radius: 14, corners: [.bottomLeft, .bottomRight])
            )
        }
        .frame(width: 150)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 3)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
