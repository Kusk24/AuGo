import SwiftUI
import FirebaseFirestore

// MARK: - Model

struct Leader: Identifiable {
    let id: String
    let name: String
    let nickname: String
    let totalPoints: Int
    let rank: Int
    
    init(user: User, rank: Int) {
        self.id = user.id ?? UUID().uuidString
        self.name = user.name
        self.nickname = user.nickname
        self.totalPoints = user.score
        self.rank = rank
    }
}

// MARK: - Main View

struct LeaderboardView: View {
    
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var leaders: [Leader] = []
    @State private var isLoading = true

    private var topThree: [Leader] { Array(leaders.prefix(3)) }
    private var others: [Leader] { Array(leaders.dropFirst(3)) }

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color.Brand.primary)
                    
                    Text("Loading leaderboard...")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            } else if leaders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.Brand.primary.opacity(0.3))
                    
                    Text("No users yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Be the first to score points!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            } else {
                List {
                    Text("Top Scorers")
                        .font(.headline)
                        .foregroundColor(Color.Brand.primary)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                        .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden, edges: [.top, .bottom])

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

                    if !others.isEmpty {
                        Text("Rankings")
                            .font(.headline)
                            .foregroundColor(Color.Brand.primary)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                            .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden, edges: [.top, .bottom])

                        ForEach(others) { leader in
                            LeaderRowView(leader: leader)
                                .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden, edges: [.top, .bottom])
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            fetchLeaderboard()
        }
        .refreshable {
            fetchLeaderboard()
        }
    }
    
    func fetchLeaderboard() {
        isLoading = true
        let db = Firestore.firestore()
        
        db.collection("users")
            .order(by: "score", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error fetching leaderboard: \(error)")
                        self.isLoading = false
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No documents in snapshot")
                        self.isLoading = false
                        return
                    }
                    
                    print("✅ Fetched \(documents.count) documents from Firestore")
                    
                    let parsedUsers: [User] = documents.compactMap { document -> User? in
                        let data = document.data()

                        // Be tolerant with legacy/incomplete user docs so leaderboard still renders.
                        let email = (data["email"] as? String) ?? ""
                        let fallbackName = email.split(separator: "@").first.map(String.init) ?? "User"
                        let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let nickname = (data["nickname"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let resolvedName = (name?.isEmpty == false) ? name! : fallbackName
                        let resolvedNickname = (nickname?.isEmpty == false) ? nickname! : resolvedName
                        let statusRaw = (data["status"] as? String) ?? "active"
                        
                        let user = User(
                            id: document.documentID,
                            studentID: (data["studentID"] as? String) ?? "",
                            name: resolvedName,
                            nickname: resolvedNickname,
                            email: email,
                            faculty: (data["faculty"] as? String) ?? "Unknown",
                            birthDate: (data["birthDate"] as? Timestamp)?.dateValue() ?? Date(),
                            joinedDate: (data["joinedDate"] as? Timestamp)?.dateValue() ?? Date(),
                            lastWarningDate: (data["lastWarningDate"] as? Timestamp)?.dateValue(),
                            warningCount: data["warningCount"] as? Int ?? 0,
                            status: User.UserStatus(rawValue: statusRaw) ?? .active,
                            score: Self.parseScore(data["score"])
                        )

                        print("✅ Parsed user: \(resolvedNickname) with score: \(user.score)")
                        return user
                    }

                    // Keep ranking contiguous and deterministic, highest score first.
                    let fetchedLeaders = parsedUsers
                        .sorted { $0.score > $1.score }
                        .enumerated()
                        .map { Leader(user: $0.element, rank: $0.offset + 1) }
                    
                    print("✅ Total leaders created: \(fetchedLeaders.count)")
                    self.leaders = fetchedLeaders
                    self.isLoading = false
                }
            }
    }

    private static func parseScore(_ value: Any?) -> Int {
        switch value {
        case let intValue as Int:
            return intValue
        case let number as NSNumber:
            return number.intValue
        case let doubleValue as Double:
            return Int(doubleValue)
        case let stringValue as String:
            return Int(stringValue) ?? 0
        default:
            return 0
        }
    }
}

// MARK: - Helper

private extension Leader {
    var displayName: String {
        nickname.isEmpty ? name : nickname
    }
    
    var avatarInitial: String {
        String(displayName.prefix(1)).uppercased()
    }
}

// MARK: - Top 3 Cards

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
                ZStack {
                    Circle()
                        .fill(Color.Brand.primary.opacity(0.2))
                        .frame(width: highlight ? 70 : 60, height: highlight ? 70 : 60)
                    
                    Text(leader.avatarInitial)
                        .font(.system(size: highlight ? 30 : 24, weight: .bold))
                        .foregroundColor(Color.Brand.primary)
                }
                .padding(.top, 12)

                Text("#\(leader.rank)")
                    .font(.subheadline.bold())
                    .foregroundColor(.gray)

                Text(leader.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("Total Points: \(leader.totalPoints)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 110, height: 150)
    }
}

// MARK: - List Rows

private struct LeaderRowView: View {
    let leader: Leader

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.Brand.primary.opacity(0.2))
                    .frame(width: 46, height: 46)

                Text(leader.avatarInitial)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.Brand.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(leader.displayName)
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
