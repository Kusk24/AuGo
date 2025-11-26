// AUGOApp.swift
import SwiftUI

@main
struct AUGOApp: App {

    @StateObject private var router = AppRouter()

    init() {
        // --- NAV BAR (Brand purple titles, like HealthyMe) ---
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.Brand.primary)
        ]
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.Brand.primary)
        ]

        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance    = navAppearance
        UINavigationBar.appearance().tintColor            = UIColor(Color.Brand.primary)

        // ⛔️ NO TAB BAR BACKGROUND COLOR HERE (Option A = white system tab bar)
        // Tab icons/text color will come from .tint(Color.Brand.primary) in RootTabView
    }

    var body: some Scene {
        WindowGroup {
            router.rootView()
                .environmentObject(router)
        }
    }
}
