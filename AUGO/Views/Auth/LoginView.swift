// LoginView.swift
import SwiftUI
import UIKit

struct LoginView: View {
    enum LoginMode {
        case student
        case announcer
    }
    
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var mode: LoginMode = .student
    @State private var announcerEmail = ""
    @State private var announcerPassword = ""
    @State private var announcerResetMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.Brand.primary.opacity(0.06)
                    .ignoresSafeArea()
                
                VStack(spacing: 28) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "location.fill.viewfinder")
                            .font(.system(size: 80))
                            .foregroundColor(Color.Brand.primary)
                        
                        Text("AUGO")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(Color.Brand.primary)
                        
                        Text("Campus AR Adventure")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if mode == .student {
                        VStack(spacing: 12) {
                            Button {
                                Task {
                                    await authManager.signInWithGoogle()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        providerIcon(assetName: "GoogleLogo", fallbackSystemName: "globe")
                                        Text("Sign in with Google")
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
                            .disabled(authManager.isLoading)

                            Button {
                                Task {
                                    await authManager.signInWithMicrosoft()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        providerIcon(assetName: "MicrosoftLogo", fallbackSystemName: "building.2.crop.circle")
                                        Text("Sign in with Microsoft")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(Color.Brand.primary.opacity(0.86))
                                )
                            }
                            .disabled(authManager.isLoading)
                        }
                        .padding(.horizontal, 32)
                        
                        Button {
                            mode = .announcer
                            authManager.errorMessage = nil
                            announcerResetMessage = nil
                        } label: {
                            Text("Are you an announcer? Sign in here")
                                .font(.caption)
                                .foregroundColor(Color.Brand.primary)
                        }
                        .disabled(authManager.isLoading)
                    } else {
                        VStack(spacing: 12) {
                            TextField("Announcer Email", text: $announcerEmail)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.Brand.primary.opacity(0.2), lineWidth: 1)
                                )
                            
                            SecureField("Password", text: $announcerPassword)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.Brand.primary.opacity(0.2), lineWidth: 1)
                                )
                            
                            Button {
                                Task {
                                    await authManager.signInAnnouncerWithEmailPassword(
                                        email: announcerEmail,
                                        password: announcerPassword
                                    )
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "person.badge.key.fill")
                                        Text("Sign in as Announcer")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(Color.Brand.primary)
                                )
                            }
                            .disabled(
                                authManager.isLoading
                                || announcerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || announcerPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                            
                            Button {
                                mode = .student
                                authManager.errorMessage = nil
                                announcerResetMessage = nil
                            } label: {
                                Text("Back to student sign in")
                                    .font(.caption)
                                    .foregroundColor(Color.Brand.primary)
                            }
                            .disabled(authManager.isLoading)
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else if let resetMessage = announcerResetMessage {
                        Text(resetMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Text(mode == .student ? "Sign in with your university Google or Microsoft account." : "Announcer sign in is separate and uses email/password.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                        .frame(height: 60)
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func providerIcon(assetName: String, fallbackSystemName: String) -> some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: 20))
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppRouter())
        .environmentObject(AuthenticationManager())
}
