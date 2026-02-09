// LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.Brand.primary.opacity(0.06)
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // MARK: Logo & Title
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
                    
                    // MARK: Sign in with Google Button
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
                                Image(systemName: "globe")
                                    .font(.system(size: 20))
                                
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
                    .padding(.horizontal, 32)
                    
                    // Error Message
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Text("Sign in with your university Google account")
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
}

#Preview {
    LoginView()
        .environmentObject(AppRouter())
        .environmentObject(AuthenticationManager())
}
