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
    @Published var notificationsEnabled: Bool
    
    private let db = Firestore.firestore()
    private var userNotificationsListener: ListenerRegistration?
    private var listeningUserID: String?
    private static let notificationsEnabledKey = "notifications_enabled"

    var unreadCount: Int {
        receivedNotifications.filter { !$0.isRead }.count
    }
    
    static let shared = NotificationManager()
    
    override init() {
        self.notificationsEnabled = UserDefaults.standard.object(forKey: Self.notificationsEnabledKey) as? Bool ?? true
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
            
            self.notificationPermissionGranted = granted
            
            if granted {
                print("✅ Notification permission granted")
                // Register for remote notifications on main thread
                UIApplication.shared.registerForRemoteNotifications()
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
        guard notificationsEnabled else {
            print("🔕 Notification preference is OFF")
            return
        }
        let granted = await requestNotificationPermission()
        guard granted else {
            print("⚠️ Cannot register device - permission not granted")
            return
        }
        print("✅ Device registered for notifications")
    }

    func startListeningForUserNotifications(userId: String) {
        listeningUserID = userId
        guard notificationsEnabled else {
            userNotificationsListener?.remove()
            userNotificationsListener = nil
            return
        }
        attachUserNotificationsListener(userId: userId, useOrderedQuery: true)
    }
    
    // MARK: - Send Local Notification
    func sendLocalNotification(title: String, body: String, identifier: String = UUID().uuidString) {
        guard notificationsEnabled, notificationPermissionGranted else {
            print("🔕 Local notification skipped: notifications disabled or permission not granted")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Trigger immediately
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Failed to send local notification: \(error.localizedDescription)")
            } else {
                print("✅ Local notification sent: \(title)")
            }
        }
    }
    
    // MARK: - Test Notification (for debugging)
    func sendTestNotification() {
        sendLocalNotification(
            title: "Test Notification",
            body: "If you see this, local notifications are working! 🎉",
            identifier: "test_\(UUID().uuidString)"
        )
    }

    private func attachUserNotificationsListener(userId: String, useOrderedQuery: Bool) {
        userNotificationsListener?.remove()
        let baseQuery = db.collection("user_notifications")
            .whereField("userId", isEqualTo: userId)
        let query = useOrderedQuery
            ? baseQuery.order(by: "createdAt", descending: true).limit(to: 100)
            : baseQuery.limit(to: 200)
        
        var isFirstLoad = true

        userNotificationsListener = query.addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        let message = error.localizedDescription
                        print("❌ user_notifications listener error: \(message)")
                        if useOrderedQuery, message.localizedCaseInsensitiveContains("requires an index") {
                            print("⚠️ user_notifications missing index; switching to fallback listener")
                            self.attachUserNotificationsListener(userId: userId, useOrderedQuery: false)
                        }
                        return
                    }

                    guard let documents = snapshot?.documents else { return }
                    if !useOrderedQuery {
                        self.receivedNotifications.removeAll()
                    }
                    
                    for doc in documents {
                        let data = doc.data()
                        let title = (data["title"] as? String) ?? "Notification"
                        let body = (data["body"] as? String) ?? (data["message"] as? String) ?? ""
                        let createdAt = self.parseFirestoreDate(data["createdAt"]) ?? Date()
                        let isRead = data["isRead"] as? Bool ?? false
                        
                        let notification = PushNotification(
                            id: doc.documentID,
                            title: title,
                            body: body,
                            data: data.reduce(into: [AnyHashable: Any]()) { result, item in
                                result[item.key] = item.value
                            },
                            receivedAt: createdAt,
                            isRead: isRead,
                            isRemote: true
                        )
                        
                        // Check if this is a new notification
                        let isNewNotification = !self.receivedNotifications.contains(where: { $0.id == notification.id })
                        
                        self.upsertNotification(notification)
                        
                        // Send local notification for new items (but not on first load)
                        if !isFirstLoad && isNewNotification {
                            self.sendLocalNotification(title: title, body: body, identifier: doc.documentID)
                        }
                    }
                    
                    if !useOrderedQuery {
                        self.receivedNotifications.sort { $0.receivedAt > $1.receivedAt }
                        if self.receivedNotifications.count > 100 {
                            self.receivedNotifications = Array(self.receivedNotifications.prefix(100))
                        }
                    }
                    
                    isFirstLoad = false
                }
            }
    }

    func stopListeningForUserNotifications() {
        userNotificationsListener?.remove()
        userNotificationsListener = nil
        listeningUserID = nil
        receivedNotifications = []
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.notificationsEnabledKey)
        if enabled {
            if let uid = listeningUserID {
                startListeningForUserNotifications(userId: uid)
                Task {
                    await registerDeviceForNotifications(userId: uid)
                }
            }
        } else {
            userNotificationsListener?.remove()
            userNotificationsListener = nil
        }
    }

    func addInAppNotification(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        data: [AnyHashable: Any] = [:]
    ) {
        guard notificationsEnabled else { return }
        
        let notification = PushNotification(
            id: id,
            title: title,
            body: body,
            data: data,
            receivedAt: Date()
        )
        
        upsertNotification(notification)
        
        // Also send a local notification
        sendLocalNotification(title: title, body: body, identifier: id)
    }

    private func upsertNotification(_ notification: PushNotification) {
        if let existingIndex = receivedNotifications.firstIndex(where: { $0.id == notification.id }) {
            receivedNotifications[existingIndex] = notification
        } else {
            receivedNotifications.insert(notification, at: 0)
        }
        receivedNotifications.sort { $0.receivedAt > $1.receivedAt }
        if receivedNotifications.count > 200 {
            receivedNotifications = Array(receivedNotifications.prefix(200))
        }
    }
    
    // MARK: - Handle Notification Tap
    func handleNotificationTap(_ notification: PushNotification) {
        print("📱 Notification tapped: \(notification.title)")
        // You can add navigation logic here based on notification type
        // For example, navigate to specific post, announcement, etc.
    }

    func markNotificationAsRead(_ notificationId: String) async {
        guard !notificationId.isEmpty else { return }

        var shouldSyncToFirestore = false
        if let idx = receivedNotifications.firstIndex(where: { $0.id == notificationId }) {
            if receivedNotifications[idx].isRead { return }
            shouldSyncToFirestore = receivedNotifications[idx].isRemote
            receivedNotifications[idx].isRead = true
        }

        guard shouldSyncToFirestore else { return }

        do {
            try await db.collection("user_notifications").document(notificationId).setData([
                "isRead": true,
                "readAt": Timestamp(date: Date())
            ], merge: true)
        } catch {
            // Non-fatal: local state already updated.
            print("⚠️ Failed to mark notification as read: \(error.localizedDescription)")
        }
    }

    func markNotificationAsUnread(_ notificationId: String) async {
        guard !notificationId.isEmpty else { return }

        var shouldSyncToFirestore = false
        if let idx = receivedNotifications.firstIndex(where: { $0.id == notificationId }) {
            if !receivedNotifications[idx].isRead { return }
            shouldSyncToFirestore = receivedNotifications[idx].isRemote
            receivedNotifications[idx].isRead = false
        }

        guard shouldSyncToFirestore else { return }

        do {
            try await db.collection("user_notifications").document(notificationId).setData([
                "isRead": false,
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        } catch {
            print("⚠️ Failed to mark notification as unread: \(error.localizedDescription)")
        }
    }

    private func parseFirestoreDate(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = value as? Date {
            return date
        }
        if let seconds = value as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }
        if let seconds = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(seconds))
        }
        if let dateString = value as? String {
            let isoWithFraction = ISO8601DateFormatter()
            isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoWithFraction.date(from: dateString) { return date }
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: dateString) { return date }
        }
        return nil
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
        
        let id = notification.request.identifier
        let title = notification.request.content.title
        let body = notification.request.content.body
        let sanitizedPayload: [String: String] = userInfo.reduce(into: [:]) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
        
        Task { @MainActor in
            let payload: [AnyHashable: Any] = sanitizedPayload.reduce(into: [:]) { result, item in
                result[item.key] = item.value
            }
            let pushNotification = PushNotification(
                id: id,
                title: title,
                body: body,
                data: payload,
                receivedAt: Date()
            )
            self.upsertNotification(pushNotification)
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
        
        let id = response.notification.request.identifier
        let title = response.notification.request.content.title
        let body = response.notification.request.content.body
        let sanitizedPayload: [String: String] = userInfo.reduce(into: [:]) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
        
        Task { @MainActor in
            let payload: [AnyHashable: Any] = sanitizedPayload.reduce(into: [:]) { result, item in
                result[item.key] = item.value
            }
            let pushNotification = PushNotification(
                id: id,
                title: title,
                body: body,
                data: payload,
                receivedAt: Date()
            )
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
    var isRead: Bool
    let isRemote: Bool

    init(id: String, title: String, body: String, data: [AnyHashable: Any], receivedAt: Date = Date(), isRead: Bool = false, isRemote: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.data = data
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.isRemote = isRemote
    }
    
    // Custom coding keys to handle [AnyHashable: Any]
    enum CodingKeys: String, CodingKey {
        case id, title, body, receivedAt, isRead, isRemote
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        receivedAt = try container.decode(Date.self, forKey: .receivedAt)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        isRemote = try container.decodeIfPresent(Bool.self, forKey: .isRemote) ?? false
        data = [:] // Default empty for decoding
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(receivedAt, forKey: .receivedAt)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(isRemote, forKey: .isRemote)
    }
}
