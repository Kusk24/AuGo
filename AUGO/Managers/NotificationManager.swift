// NotificationManager.swift
import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    @Published var fcmToken: String?
    @Published var notificationPermissionGranted = false
    @Published var receivedNotifications: [PushNotification] = []
    
    private let db = Firestore.firestore()
    
    static let shared = NotificationManager()
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    // MARK: - Setup Notifications
    func setupNotifications() {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        print("🔔 NotificationManager initialized")
    }
    
    // MARK: - Request Permission
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            
            await MainActor.run {
                self.notificationPermissionGranted = granted
            }
            
            if granted {
                print("✅ Notification permission granted")
                // Register for remote notifications on main thread
                await UIApplication.shared.registerForRemoteNotifications()
            } else {
                print("❌ Notification permission denied")
            }
            
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error)")
            return false
        }
    }
    
    // MARK: - Register Device for Notifications
    func registerDeviceForNotifications(userId: String) async {
        let granted = await requestNotificationPermission()
        guard granted else {
            print("⚠️ Cannot register device - permission not granted")
            return
        }
        print("✅ Device registered for notifications")
    }
    
    // MARK: - Handle Notification Tap
    func handleNotificationTap(_ notification: PushNotification) {
        print("📱 Notification tapped: \(notification.title)")
        // You can add navigation logic here based on notification type
        // For example, navigate to specific post, announcement, etc.
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("📬 Notification received in foreground: \(userInfo)")
        
        // Create notification object
        let pushNotification = PushNotification(
            id: notification.request.identifier,
            title: notification.request.content.title,
            body: notification.request.content.body,
            data: userInfo
        )
        
        Task { @MainActor in
            self.receivedNotifications.insert(pushNotification, at: 0)
        }
        
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 Notification tapped: \(userInfo)")
        
        // Create notification object
        let pushNotification = PushNotification(
            id: response.notification.request.identifier,
            title: response.notification.request.content.title,
            body: response.notification.request.content.body,
            data: userInfo
        )
        
        Task { @MainActor in
            self.handleNotificationTap(pushNotification)
        }
        
        completionHandler()
    }
}

// MARK: - PushNotification Model
struct PushNotification: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let data: [AnyHashable: Any]
    let receivedAt: Date
    
    init(id: String, title: String, body: String, data: [AnyHashable: Any]) {
        self.id = id
        self.title = title
        self.body = body
        self.data = data
        self.receivedAt = Date()
    }
    
    // Custom coding keys to handle [AnyHashable: Any]
    enum CodingKeys: String, CodingKey {
        case id, title, body, receivedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        receivedAt = try container.decode(Date.self, forKey: .receivedAt)
        data = [:] // Default empty for decoding
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(receivedAt, forKey: .receivedAt)
    }
}
