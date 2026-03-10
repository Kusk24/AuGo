import SwiftUI
import UIKit

enum ARRarityPalette {
    struct Level: Identifiable {
        let key: String
        let label: String
        var id: String { key }
    }

    static let orderedLevels: [Level] = [
        Level(key: "mythic", label: "Mythic"),
        Level(key: "legendary", label: "Legendary"),
        Level(key: "epic", label: "Epic"),
        Level(key: "rare", label: "Rare"),
        Level(key: "uncommon", label: "Uncommon"),
        Level(key: "common", label: "Common")
    ]

    static func accentColor(for rarity: String?) -> Color {
        let normalized = normalize(rarity)
        switch normalized {
        case "mythic":
            return dynamicColor(light: UIColor(red: 0.820, green: 0.176, blue: 0.176, alpha: 1.0),
                                dark: UIColor(red: 0.980, green: 0.412, blue: 0.412, alpha: 1.0))
        case "legendary":
            return dynamicColor(light: UIColor(red: 0.910, green: 0.710, blue: 0.118, alpha: 1.0),
                                dark: UIColor(red: 0.980, green: 0.824, blue: 0.361, alpha: 1.0))
        case "epic":
            return dynamicColor(light: UIColor(red: 0.525, green: 0.247, blue: 0.761, alpha: 1.0),
                                dark: UIColor(red: 0.714, green: 0.486, blue: 0.925, alpha: 1.0))
        case "rare":
            return dynamicColor(light: UIColor(red: 0.145, green: 0.388, blue: 0.922, alpha: 1.0),
                                dark: UIColor(red: 0.376, green: 0.647, blue: 0.980, alpha: 1.0))
        case "uncommon":
            return dynamicColor(light: UIColor(red: 0.086, green: 0.639, blue: 0.290, alpha: 1.0),
                                dark: UIColor(red: 0.290, green: 0.871, blue: 0.502, alpha: 1.0))
        case "common":
            return dynamicColor(light: UIColor(red: 0.294, green: 0.333, blue: 0.388, alpha: 1.0),
                                dark: UIColor(red: 0.612, green: 0.639, blue: 0.686, alpha: 1.0))
        default:
            return dynamicColor(light: UIColor(red: 0.294, green: 0.333, blue: 0.388, alpha: 1.0),
                                dark: UIColor(red: 0.612, green: 0.639, blue: 0.686, alpha: 1.0))
        }
    }

    static func gradientColors(for rarity: String?) -> [Color] {
        let accent = accentColor(for: rarity)
        return [accent.opacity(0.85), accent.opacity(0.52), accent.opacity(0.24)]
    }

    static func normalize(_ rarity: String?) -> String {
        let raw = rarity?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !raw.isEmpty else { return "" }

        // Canonical keys for the current rarity system.
        switch raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ") {
        case "mythic":
            return "mythic"
        case "legendary":
            return "legendary"
        case "epic":
            return "epic"
        case "rare":
            return "rare"
        case "uncommon":
            return "uncommon"
        case "common":
            return "common"

        // Temporary compatibility with older rarity naming.
        case "ultra rare":
            return "mythic"
        case "very common", "unlimited":
            return "common"
        default:
            return raw
        }
    }

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}
