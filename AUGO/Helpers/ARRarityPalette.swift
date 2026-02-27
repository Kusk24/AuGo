import SwiftUI
import UIKit

enum ARRarityPalette {
    static func accentColor(for rarity: String?) -> Color {
        let normalized = normalize(rarity)
        switch normalized {
        case "ultra rare":
            return dynamicColor(light: UIColor(red: 0.031, green: 0.569, blue: 0.698, alpha: 1.0),
                                dark: UIColor(red: 0.133, green: 0.827, blue: 0.933, alpha: 1.0))
        case "rare":
            return dynamicColor(light: UIColor(red: 0.145, green: 0.388, blue: 0.922, alpha: 1.0),
                                dark: UIColor(red: 0.376, green: 0.647, blue: 0.980, alpha: 1.0))
        case "uncommon":
            return dynamicColor(light: UIColor(red: 0.086, green: 0.639, blue: 0.290, alpha: 1.0),
                                dark: UIColor(red: 0.290, green: 0.871, blue: 0.502, alpha: 1.0))
        case "common":
            return dynamicColor(light: UIColor(red: 0.859, green: 0.153, blue: 0.467, alpha: 1.0),
                                dark: UIColor(red: 0.957, green: 0.447, blue: 0.714, alpha: 1.0))
        case "very common":
            return dynamicColor(light: UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1.0),
                                dark: UIColor(red: 0.973, green: 0.443, blue: 0.443, alpha: 1.0))
        case "unlimited":
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
        rarity?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}
