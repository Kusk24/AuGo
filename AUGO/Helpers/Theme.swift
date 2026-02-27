import SwiftUI
import Combine

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
}

@MainActor
final class AppThemeManager: ObservableObject {
    private let storageKey = "augo.theme.mode"
    private let legacyStorageKey = "augo.theme.night_mode_enabled"
    @Published private(set) var mode: AppThemeMode

    init() {
        if let stored = UserDefaults.standard.string(forKey: storageKey),
           let storedMode = AppThemeMode(rawValue: stored) {
            mode = storedMode
            return
        }

        // Backward compatibility with old boolean key.
        if UserDefaults.standard.object(forKey: legacyStorageKey) != nil {
            let oldNightMode = UserDefaults.standard.bool(forKey: legacyStorageKey)
            mode = oldNightMode ? .dark : .light
            UserDefaults.standard.set(mode.rawValue, forKey: storageKey)
            return
        }

        mode = .system
    }

    var preferredColorScheme: ColorScheme? {
        switch mode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var isNightModeEnabled: Bool {
        mode == .dark
    }

    func toggleNightMode() {
        setMode(mode == .dark ? .light : .dark)
    }

    func setNightMode(_ enabled: Bool) {
        setMode(enabled ? .dark : .light)
    }

    func setMode(_ newMode: AppThemeMode) {
        guard newMode != mode else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: storageKey)
    }
}

struct Theme {
    static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Color.Brand.surface)

        // Title colors
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.Brand.primary),
            .font: UIFont.systemFont(ofSize: 36, weight: .bold)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.Brand.primary),
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold)
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
