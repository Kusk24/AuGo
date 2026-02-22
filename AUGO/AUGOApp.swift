// AUGOApp.swift
import SwiftUI
import FirebaseCore
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

// MARK: - AppDelegate for Remote Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        print("🚀 App launched")
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Setup notification center
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        return true
    }
    
    // Handle remote notification registration
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 Device token received")
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #else
        // FirebaseMessaging not available; skip assigning APNS token
        #endif
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
    @StateObject private var themeManager = AppThemeManager()

    init() {
        Theme.apply()
    }

    var body: some Scene {
        WindowGroup {
            router.rootView()
                .environmentObject(router)
                .environmentObject(authManager)
                .environmentObject(notificationManager)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .onAppear {
                    // Connect router to auth state changes
                    router.observeAuthState(authManager: authManager)
                }
        }
    }
}
