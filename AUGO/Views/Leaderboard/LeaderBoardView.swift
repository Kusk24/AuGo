import SwiftUI

// MARK: - Model

struct Leader: Identifiable {
    let id = UUID()
    let name: String
    let totalPoints: Int
    let rank: Int
}

// MARK: - Main View

struct LeaderboardView: View {

    private let leaders: [Leader] = [
        .init(name: "Tim",     totalPoints: 2000, rank: 1),
        .init(name: "Damian",  totalPoints: 1800, rank: 2),
        .init(name: "Richard", totalPoints: 1700, rank: 3),
        .init(name: "User",    totalPoints: 1500, rank: 4),
        .init(name: "User",    totalPoints: 1400, rank: 5),
        .init(name: "User",    totalPoints: 1300, rank: 6),
        .init(name: "Jason",   totalPoints: 1200, rank: 7),
        .init(name: "User",    totalPoints: 1100, rank: 8),
        .init(name: "User",    totalPoints: 1000, rank: 9),
        .init(name: "User",    totalPoints: 900,  rank: 10)
    ]

    private var topThree: [Leader]  { Array(leaders.prefix(3)) }
    private var others:   [Leader]  { Array(leaders.dropFirst(3)) }

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            List {
                // --- TOP SCORERS TITLE ---
                Text("Top Scorers")
                    .font(.headline)
                    .foregroundColor(Color.Brand.primary)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden, edges: [.top, .bottom])

                // --- TOP 3 CARDS ---
                HStack(spacing: 16) {
                    Spacer(minLength: 0)

                    if topThree.count >= 2 {
                        TopLeaderCardView(leader: topThree[1], highlight: false)
                    }
                    if topThree.count >= 1 {
                        TopLeaderCardView(leader: topThree[0], highlight: true)
                    }
                    if topThree.count >= 3 {
                        TopLeaderCardView(leader: topThree[2], highlight: false)
                    }

                    Spacer(minLength: 0)
                }
                .listRowInsets(.init(top: 0, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden, edges: [.top, .bottom])

                // --- RANKINGS TITLE ---
                Text("Rankings")
                    .font(.headline)
                    .foregroundColor(Color.Brand.primary)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden, edges: [.top, .bottom])

                // --- RANKINGS ROWS (gray cards) ---
                ForEach(others) { leader in
                    LeaderRowView(leader: leader)
                        .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden, edges: [.top, .bottom])
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Helper for avatars

private extension Leader {
    var hasCustomAvatar: Bool {
        ["Tim", "Damian", "Richard", "Jason"].contains(name)
    }

    var avatarImage: Image {
        hasCustomAvatar ? Image(name) : Image(systemName: "person.circle.fill")
    }
}

// MARK: - Top 3 cards

private struct TopLeaderCardView: View {
    let leader: Leader
    let highlight: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
                .shadow(
                    color: .black.opacity(0.12),
                    radius: highlight ? 6 : 3,
                    y: highlight ? 4 : 2
                )

            VStack(spacing: 8) {

                // CLEAN CIRCLE AVATAR (no purple background)
                leader.avatarImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: highlight ? 70 : 60,
                           height: highlight ? 70 : 60)
                    .clipShape(Circle())
                    .padding(.top, 12)

                Text("#\(leader.rank)")
                    .font(.subheadline.bold())
                    .foregroundColor(.gray)

                Text(leader.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text("Total Points: \(leader.totalPoints)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 110, height: 150)
    }
}

// MARK: - List rows (gray card style)

private struct LeaderRowView: View {
    let leader: Leader

    var body: some View {
        HStack(spacing: 12) {

            ZStack {
                Circle()
                    .fill(Color.Brand.primary.opacity(0.06))   // subtle background
                    .frame(width: 46, height: 46)

                leader.avatarImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .foregroundColor(Color.Brand.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(leader.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text("Total Points: \(leader.totalPoints)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("#\(leader.rank)")
                .font(.subheadline.bold())
                .foregroundColor(.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(.white)
        )
        .padding(.vertical, 4)
    }
}
