import SwiftUI
import PhotosUI
import UIKit
import FirebaseCore

struct CreateAnnouncementView: View {
    
    @Binding var isPresentedFromHome: Bool
    let editingAnnouncement: Announcement?
    let onSubmitSuccess: (() -> Void)?
    
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var announcementManager = AnnouncementManager()
    
    @State private var title = ""
    @State private var content = ""
    @State private var link = ""
    @State private var coinRewardText = "0.2"
    @State private var isUrgent = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60*60*24)
    
    @State private var navigateToMap = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhotos: [UIImage] = []
    @State private var existingPhotoPaths: [String] = []
    @State private var isLoadingPhotos = false

    init(
        isPresentedFromHome: Binding<Bool>,
        editingAnnouncement: Announcement? = nil,
        onSubmitSuccess: (() -> Void)? = nil
    ) {
        _isPresentedFromHome = isPresentedFromHome
        self.editingAnnouncement = editingAnnouncement
        self.onSubmitSuccess = onSubmitSuccess
        _title = State(initialValue: editingAnnouncement?.title ?? "")
        _content = State(initialValue: editingAnnouncement?.body ?? "")
        _link = State(initialValue: editingAnnouncement?.link ?? "")
        _coinRewardText = State(initialValue: String(format: "%.1f", editingAnnouncement?.coinReward ?? 0.2))
        _isUrgent = State(initialValue: editingAnnouncement?.isUrgent ?? false)
        _startDate = State(initialValue: editingAnnouncement?.startDate ?? Date())
        _endDate = State(initialValue: editingAnnouncement?.endDate ?? Date().addingTimeInterval(60*60*24))
        _existingPhotoPaths = State(initialValue: editingAnnouncement?.photoPaths ?? [])
    }
    
    private var canProceed: Bool {
        !title.isEmpty
        && !content.isEmpty
        && startDate <= endDate
        && coinRewardValue >= 0
        && !isLoadingPhotos
    }

    private var coinRewardValue: Double {
        let normalized = coinRewardText.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    private var remainingPhotoSlots: Int {
        max(0, 2 - existingPhotoPaths.count)
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
                    TextField("Coin reward per reaction", text: $coinRewardText)
                        .keyboardType(.decimalPad)
                }

                Section("Photos") {
                    if remainingPhotoSlots > 0 {
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: remainingPhotoSlots,
                            matching: .images
                        ) {
                            Label("Add up to \(remainingPhotoSlots) photo\(remainingPhotoSlots == 1 ? "" : "s")", systemImage: "photo.on.rectangle.angled")
                                .font(.subheadline.weight(.semibold))
                        }
                    } else {
                        Label("Max 2 photos reached", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                    }

                    if isLoadingPhotos {
                        ProgressView("Loading photos...")
                            .font(.caption)
                    }

                    if !existingPhotoPaths.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(existingPhotoPaths.enumerated()), id: \.offset) { index, path in
                                    if let url = storageDownloadURL(for: path) {
                                        ZStack(alignment: .topTrailing) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .empty:
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(Color(UIColor.systemGray5))
                                                        ProgressView()
                                                    }
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                case .failure:
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(Color(UIColor.systemGray5))
                                                        Image(systemName: "photo")
                                                            .foregroundColor(.secondary)
                                                    }
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                            .frame(width: 96, height: 96)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))

                                            Button {
                                                existingPhotoPaths.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.4))
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 6, y: -6)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if !selectedPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(selectedPhotos.enumerated()), id: \.offset) { index, photo in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: photo)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 96, height: 96)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))

                                        Button {
                                            selectedPhotos.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.4))
                                                .clipShape(Circle())
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section("Schedule") {
                    DatePicker("Start Date", selection: $startDate)
                    DatePicker("End Date", selection: $endDate)
                }
            }
            
            Button {
                navigateToMap = true
            } label: {
                Text(isLoadingPhotos
                     ? "Loading photos..."
                     : (editingAnnouncement == nil ? "Choose Location" : "Update & Resubmit"))
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
                coinReward: coinRewardValue,
                isUrgent: isUrgent,
                startDate: startDate,
                endDate: endDate,
                initialCoordinate: editingAnnouncement?.coordinate,
                keptExistingPhotoPaths: existingPhotoPaths,
                photoDatas: selectedPhotos.compactMap { $0.jpegData(compressionQuality: 0.82) },
                onSubmitSuccess: onSubmitSuccess
            )
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task { await loadSelectedPhotos(from: newItems) }
        }
    }

    @MainActor
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(image)
            }
        }
        selectedPhotos = Array(loaded.prefix(remainingPhotoSlots))
    }

    private func storageDownloadURL(for assetPath: String) -> URL? {
        guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let escapedPath = assetPath.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
    }
}
