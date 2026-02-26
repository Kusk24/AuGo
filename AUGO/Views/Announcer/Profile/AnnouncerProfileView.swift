import SwiftUI

struct AnnouncerProfileView: View {
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var themeManager: AppThemeManager
    
    var body: some View {
        ZStack {
            Color.Brand.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    
                    // HEADER
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 90, height: 90)
                            .foregroundColor(Color.Brand.primary)
                        
                        Text(announcer.name)
                            .font(.title2.bold())
                        
                        Text(announcer.affiliationName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)
                    
                    // INFO CARD
                    VStack(spacing: 16) {
                        InfoRow(title: "Role", value: announcer.role)
                        InfoRow(title: "Email", value: announcer.email)
                        InfoRow(title: "Phone", value: announcer.phone)
                    }
                    .padding()
                    .background(Color.Brand.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack {
                        Text("Notification Preferences")
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { notificationManager.notificationsEnabled },
                            set: { notificationManager.setNotificationsEnabled($0) }
                        ))
                        .labelsHidden()
                        .tint(Color.Brand.primary)
                    }
                    .padding()
                    .background(Color.Brand.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Theme", systemImage: themeManager.mode.iconName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                        }

                        Picker("Theme", selection: Binding(
                            get: { themeManager.mode },
                            set: { themeManager.setMode($0) }
                        )) {
                            ForEach(AppThemeMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Color.Brand.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // SIGN OUT
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        Text("Sign Out")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.top, 12)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
    
    // MARK: - Helpers
    private var announcer: Announcer {
        authManager.announcerProfile!
    }
}
