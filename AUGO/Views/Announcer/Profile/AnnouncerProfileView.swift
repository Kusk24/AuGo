import SwiftUI

struct AnnouncerProfileView: View {
    
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
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
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // SIGN OUT
                Button(role: .destructive) {
                    authManager.signOut()
                } label: {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 12)
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Helpers
    private var announcer: Announcer {
        authManager.announcerProfile!
    }
}
