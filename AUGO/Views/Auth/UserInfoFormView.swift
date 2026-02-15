// UserInfoFormView.swift
import SwiftUI
import FirebaseAuth

struct UserInfoFormView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var nickname = ""
    @State private var realName = ""
    @State private var selectedMajor = "Computer Science"
    @State private var birthDate = Date()
    @State private var showDatePicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let majors = [
        "Computer Science",
        "Engineering",
        "Business Administration",
        "Psychology",
        "Biology",
        "Mathematics",
        "Physics",
        "Chemistry",
        "Economics",
        "English Literature",
        "Art & Design",
        "Communications"
    ]
    
    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color.Brand.primary)
                        
                        Text("Complete Your Profile")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text("Tell us a bit about yourself")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 8)
                    
                    // MARK: Form Fields
                    VStack(spacing: 20) {
                        // Student ID
                        ReadOnlyFormField(
                            label: "Student ID",
                            icon: "number",
                            value: derivedStudentID.isEmpty ? "No ID found in email" : derivedStudentID
                        )
                        
                        // Real Name
                        FormField(
                            label: "Full Name",
                            icon: "person.fill",
                            placeholder: "Enter your full name",
                            text: $realName
                        )
                        .textContentType(.name)
                        
                        // Nickname
                        FormField(
                            label: "Nickname",
                            icon: "at",
                            placeholder: "Enter your nickname",
                            text: $nickname
                        )
                        
                        // Major (Dropdown)
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Major", systemImage: "graduationcap.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(majors, id: \.self) { major in
                                    Button {
                                        selectedMajor = major
                                    } label: {
                                        HStack {
                                            Text(major)
                                            if selectedMajor == major {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedMajor)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.systemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.Brand.primary.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Birth Date (Calendar)
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Birth Date", systemImage: "calendar")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Button {
                                showDatePicker.toggle()
                            } label: {
                                HStack {
                                    Text(birthDate, style: .date)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "calendar")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.systemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.Brand.primary.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            if showDatePicker {
                                DatePicker(
                                    "",
                                    selection: $birthDate,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .tint(Color.Brand.primary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.systemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.Brand.primary.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // MARK: Continue Button
                    Button {
                        saveProfile()
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Continue")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.Brand.primary)
                        )
                    }
                    .disabled(authManager.isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.6)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    // Error Message
                    if showError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                        .frame(height: 32)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile Setup")
                    .font(.headline)
                    .foregroundColor(Color.Brand.primary)
            }
        }
    }
    
    // MARK: - Validation
    var isFormValid: Bool {
        !derivedStudentID.isEmpty &&
        !realName.isEmpty &&
        !nickname.isEmpty
    }

    private var derivedStudentID: String {
        guard let email = authManager.user?.email else { return "" }
        let localPart = email.split(separator: "@").first.map(String.init) ?? ""
        let trimmedPrefix = localPart.hasPrefix("u") || localPart.hasPrefix("U")
            ? String(localPart.dropFirst())
            : localPart
        let digits = trimmedPrefix.filter(\.isNumber)
        return digits
    }
    
    // MARK: - Save Profile
    func saveProfile() {
        guard isFormValid else {
            errorMessage = "Please fill in all required fields"
            showError = true
            return
        }
        
        guard let email = authManager.user?.email else {
            errorMessage = "Email not found"
            showError = true
            return
        }
        
        guard let uid = authManager.user?.uid else {
            errorMessage = "User ID not found"
            showError = true
            return
        }
        
        let profile = User(
            id: uid,
            studentID: derivedStudentID,
            name: realName,
            nickname: nickname,
            email: email,
            faculty: selectedMajor,
            birthDate: birthDate,
            joinedDate: Date(),
            lastWarningDate: nil,
            warningCount: 0,
            status: .active,
            score: 0
        )
        
        Task {
            do {
                try await authManager.createOrUpdateUserProfile(uid: uid, profile: profile)
            } catch {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Reusable Form Field Component
struct FormField: View {
    let label: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            HStack {
                TextField(placeholder, text: $text)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.Brand.primary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct ReadOnlyFormField: View {
    let label: String
    let icon: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)

            Text(value)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.Brand.primary.opacity(0.18), lineWidth: 1)
                )
        }
    }
}

#Preview {
    NavigationStack {
        UserInfoFormView()
            .environmentObject(AppRouter())
            .environmentObject(AuthenticationManager())
    }
}
