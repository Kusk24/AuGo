// AUGOApp.swift
import SwiftUI
import FirebaseCore

@main
struct AUGOApp: App {

    @StateObject private var router = AppRouter()
    @StateObject private var authManager = AuthenticationManager()
    
    // --- ADD THESE NEW MANAGERS ---
    @StateObject private var postManager = PostManager()
    @StateObject private var mapViewModel = CampusMapViewModel()
    @StateObject private var announcementCenter = AnnouncementCenter()

    init() {
        FirebaseApp.configure()
        
        // Navigation Bar Appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.Brand.primary)]
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.Brand.primary)]

        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance    = navAppearance
        UINavigationBar.appearance().tintColor            = UIColor(Color.Brand.primary)
    }

    var body: some Scene {
        WindowGroup {
            router.rootView()
                .environmentObject(router)
                .environmentObject(authManager)
                // --- INJECT THE NEW OBJECTS HERE ---
                .environmentObject(postManager)
                .environmentObject(mapViewModel)
                .environmentObject(announcementCenter)
                .onAppear {
                    router.observeAuthState(authManager: authManager)
                }
        }
    }
}
