// NotificationListView.swift
import SwiftUI

struct NotificationListView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedNotification: PushNotification?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.Brand.appBackground
                    .ignoresSafeArea()
                
                if notificationManager.receivedNotifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No Notifications")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.gray)
                        
                        Text("You'll see notifications here when you receive them")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notificationManager.receivedNotifications) { notification in
                                NotificationCard(notification: notification)
                                    .onTapGesture {
                                        Task {
                                            if !notification.isRead {
                                                await notificationManager.markNotificationAsRead(notification.id)
                                            }
                                            let latestNotification = notificationManager.receivedNotifications.first(where: { $0.id == notification.id }) ?? notification
                                            selectedNotification = latestNotification
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .alert(item: $selectedNotification) { notification in
                if notification.isRead {
                    return Alert(
                        title: Text(notification.title),
                        message: Text(notification.body),
                        primaryButton: .default(Text("Mark as Unread")) {
                            Task {
                                await notificationManager.markNotificationAsUnread(notification.id)
                            }
                        },
                        secondaryButton: .cancel(Text("Close"))
                    )
                }
                return Alert(
                    title: Text(notification.title),
                    message: Text(notification.body),
                    primaryButton: .default(Text("Mark as Unread")) {
                        Task {
                            await notificationManager.markNotificationAsUnread(notification.id)
                        }
                    },
                    secondaryButton: .cancel(Text("Close"))
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.Brand.primary)
                }
            }
        }
    }
}

struct NotificationCard: View {
    let notification: PushNotification
    
    private var timeAgo: String {
        let interval = Date().timeIntervalSince(notification.receivedAt)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else {
            let minutes = max(1, Int(interval / 60))
            return "\(minutes)m ago"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(notification.isRead ? Color.Brand.primary.opacity(0.65) : .red)
                    .font(.system(size: 16))
                
                Text(notification.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()

                if !notification.isRead {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
                
                Text(timeAgo)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(notification.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(notification.isRead ? Color.Brand.surface : Color.Brand.surface.opacity(0.92))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
}

#Preview {
    NotificationListView()
        .environmentObject(NotificationManager.shared)
}
