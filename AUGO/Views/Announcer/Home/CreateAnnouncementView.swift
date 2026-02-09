import SwiftUI

struct CreateAnnouncementView: View {
    
    @Binding var isPresentedFromHome: Bool
    
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var announcementManager = AnnouncementManager()
    
    @State private var title = ""
    @State private var content = ""
    @State private var link = ""
    @State private var isUrgent = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60*60*24)
    
    @State private var navigateToMap = false
    
    private var canProceed: Bool {
        !title.isEmpty && !content.isEmpty && startDate <= endDate
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            Form {
                Section("Announcement") {
                    TextField("Title", text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                }
                
                Section("Details") {
                    Toggle("Urgent", isOn: $isUrgent)
                    TextField("Link (optional)", text: $link)
                }
                
                Section("Schedule") {
                    DatePicker("Start Date", selection: $startDate)
                    DatePicker("End Date", selection: $endDate)
                }
            }
            
            Button {
                navigateToMap = true
            } label: {
                Text("Choose Location")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canProceed)
            .padding()
        }
        .navigationTitle("Create Announcement")
        .navigationDestination(isPresented: $navigateToMap) {
            CreateAnnouncementMapView(
                isPresentedFromHome: $isPresentedFromHome,
                title: title,
                content: content,
                link: link.isEmpty ? nil : link,
                isUrgent: isUrgent,
                startDate: startDate,
                endDate: endDate
            )
        }
    }
}
