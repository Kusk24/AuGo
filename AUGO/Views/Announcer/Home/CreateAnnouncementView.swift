import SwiftUI

struct CreateAnnouncementView: View {
    
    @Binding var isPresentedFromHome: Bool
    let editingAnnouncement: Announcement?
    
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var announcementManager = AnnouncementManager()
    
    @State private var title = ""
    @State private var content = ""
    @State private var link = ""
    @State private var isUrgent = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60*60*24)
    
    @State private var navigateToMap = false

    init(
        isPresentedFromHome: Binding<Bool>,
        editingAnnouncement: Announcement? = nil
    ) {
        _isPresentedFromHome = isPresentedFromHome
        self.editingAnnouncement = editingAnnouncement
        _title = State(initialValue: editingAnnouncement?.title ?? "")
        _content = State(initialValue: editingAnnouncement?.body ?? "")
        _link = State(initialValue: editingAnnouncement?.link ?? "")
        _isUrgent = State(initialValue: editingAnnouncement?.isUrgent ?? false)
        _startDate = State(initialValue: editingAnnouncement?.startDate ?? Date())
        _endDate = State(initialValue: editingAnnouncement?.endDate ?? Date().addingTimeInterval(60*60*24))
    }
    
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
                Text(editingAnnouncement == nil ? "Choose Location" : "Update & Resubmit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canProceed)
            .padding()
        }
        .navigationTitle(editingAnnouncement == nil ? "Create Announcement" : "Edit Announcement")
        .navigationDestination(isPresented: $navigateToMap) {
            CreateAnnouncementMapView(
                isPresentedFromHome: $isPresentedFromHome,
                announcementID: editingAnnouncement?.id,
                title: title,
                content: content,
                link: link.isEmpty ? nil : link,
                isUrgent: isUrgent,
                startDate: startDate,
                endDate: endDate,
                initialCoordinate: editingAnnouncement?.coordinate
            )
        }
    }
}
