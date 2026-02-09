// AUGOApp.swift
import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// MARK: - AppDelegate for Remote Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        print("🚀 App launched")
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Setup Firebase Messaging
        Messaging.messaging().delegate = NotificationManager.shared
        
        // Setup notification center
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        return true
    }
    
    // Handle remote notification registration
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 Device token received")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}

@main
struct AUGOApp: App {
    
    // Register AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var router = AppRouter()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var notificationManager = NotificationManager.shared

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
                .environmentObject(authManager)
                .environmentObject(notificationManager)
                .onAppear {
                    // Connect router to auth state changes
                    router.observeAuthState(authManager: authManager)
                }
        }
    }
}
