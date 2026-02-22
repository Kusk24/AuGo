import SwiftUI
import Combine

@MainActor
final class AppThemeManager: ObservableObject {
    private let storageKey = "augo.theme.night_mode_enabled"
    @Published private(set) var isNightModeEnabled: Bool

    init() {
        isNightModeEnabled = UserDefaults.standard.bool(forKey: storageKey)
    }

    var preferredColorScheme: ColorScheme? {
        isNightModeEnabled ? .dark : .light
    }

    func toggleNightMode() {
        setNightMode(!isNightModeEnabled)
    }

    func setNightMode(_ enabled: Bool) {
        guard enabled != isNightModeEnabled else { return }
        isNightModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: storageKey)
    }
}

struct Theme {
    static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Color.Brand.surface)

        // Title colors
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(Color.Brand.primary)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.backgroundColor = UIColor(Color.Brand.surface)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
