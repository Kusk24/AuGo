// AppRouter.swift
import SwiftUI
import Combine

final class AppRouter: ObservableObject {
    @Published var isCheckingAuth = true
    @Published var isAuthenticated = false
    @Published var role: AccountRole = .unknown
    @Published var isProfileComplete = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func observeAuthState(authManager: AuthenticationManager) {
        authManager.$isCheckingAuth
            .assign(to: &$isCheckingAuth)
        
        authManager.$isAuthenticated
            .assign(to: &$isAuthenticated)
        
        authManager.$role
            .assign(to: &$role)
        
        authManager.$isProfileComplete
            .assign(to: &$isProfileComplete)
    }
    
    @ViewBuilder
    func rootView() -> some View {
        if isCheckingAuth {
            LoadingView()
            
        } else if !isAuthenticated {
            LoginView()
            
        } else {
            switch role {
            case .announcer:
                AnnouncerRootTabView()
                
            case .user:
                if isProfileComplete {
                    RootTabView()
                } else {
                    UserInfoFormView()
                }
                
            case .unknown:
                LoginView()
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.Brand.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(Color.Brand.primary)
                
                Text("Loading...")
                    .foregroundColor(.gray)
            }
        }
    }
}
