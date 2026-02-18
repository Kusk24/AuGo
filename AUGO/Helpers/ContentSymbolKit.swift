import SwiftUI

enum ContentSymbolKit {
    struct PostVisual {
        let symbol: String
        let color: Color
    }

    static func postVisual(for category: PostCategory) -> PostVisual {
        switch category {
        case .casual:
            return PostVisual(symbol: "bubble.left.and.text.bubble.right.fill", color: .yellow)
        case .lostFound:
            return PostVisual(symbol: "mappin.and.ellipse", color: .teal)
        case .complaint:
            return PostVisual(symbol: "exclamationmark.triangle.fill", color: .purple)
        case .event:
            return PostVisual(symbol: "calendar.badge.clock", color: .orange)
        case .question:
            return PostVisual(symbol: "questionmark.circle.fill", color: .blue)
        case .announcement:
            return PostVisual(symbol: "megaphone.fill", color: .gray)
        case .arChallenge:
            return PostVisual(symbol: "arkit", color: .green)
        }
    }

    static func postVisual(for category: Post.PostCategory) -> PostVisual {
        switch category {
        case .casual:
            return PostVisual(symbol: "bubble.left.and.text.bubble.right.fill", color: .yellow)
        case .lostFound:
            return PostVisual(symbol: "mappin.and.ellipse", color: .teal)
        case .complaint:
            return PostVisual(symbol: "exclamationmark.triangle.fill", color: .purple)
        case .event:
            return PostVisual(symbol: "calendar.badge.clock", color: .orange)
        case .question:
            return PostVisual(symbol: "questionmark.circle.fill", color: .blue)
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
