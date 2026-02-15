import SwiftUI

enum ContentSymbolKit {
    struct PostVisual {
        let symbol: String
        let color: Color
    }

    static func postVisual(for category: PostCategory) -> PostVisual {
        switch category {
        case .casual:
            return PostVisual(symbol: "bubble.left.and.text.bubble.right.fill", color: .teal)
        case .lostFound:
            return PostVisual(symbol: "magnifyingglass.circle.fill", color: .red)
        case .complaint:
            return PostVisual(symbol: "exclamationmark.bubble.fill", color: Color(red: 1.0, green: 0.84, blue: 0.0))
        case .event:
            return PostVisual(symbol: "calendar.badge.clock", color: .purple)
        case .question:
            return PostVisual(symbol: "questionmark.circle.fill", color: .blue)
        case .announcement:
            return PostVisual(symbol: "megaphone.fill", color: .orange)
        case .arChallenge:
            return PostVisual(symbol: "arkit", color: .green)
        }
    }

    static func postVisual(for category: Post.PostCategory) -> PostVisual {
        switch category {
        case .casual:
            return PostVisual(symbol: "bubble.left.and.text.bubble.right.fill", color: .teal)
        case .event:
            return PostVisual(symbol: "calendar.badge.clock", color: .purple)
        case .question:
            return PostVisual(symbol: "questionmark.circle.fill", color: .blue)
        case .announcement:
            return PostVisual(symbol: "megaphone.fill", color: .orange)
        case .arChallenge:
            return PostVisual(symbol: "arkit", color: .green)
        }
    }

    static func arCharacterSymbol(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("fox") || lower.contains("cat") || lower.contains("dog") || lower.contains("animal") {
            return "pawprint.fill"
        }
        if lower.contains("robot") || lower.contains("mech") || lower.contains("cyber") {
            return "cpu.fill"
        }
        if lower.contains("ghost") || lower.contains("spirit") || lower.contains("phantom") {
            return "sparkles.rectangle.stack.fill"
        }
        if lower.contains("bird") {
            return "bird.fill"
        }
        return "sparkles"
    }
}
