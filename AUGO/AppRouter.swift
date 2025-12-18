// AppRouter.swift
import SwiftUI
import Combine

final class AppRouter: ObservableObject {
    @Published var isLocked: Bool = true
    @Published var isCheckingAuth: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {}
    
    func observeAuthState(authManager: AuthenticationManager) {
        // Observe checking state
        authManager.$isCheckingAuth
            .assign(to: &$isCheckingAuth)
        
        // Auto-navigate based on authentication state
        authManager.$isAuthenticated
            .combineLatest(authManager.$isProfileComplete)
            .sink { [weak self] isAuthenticated, isProfileComplete in
                // User is logged in and has completed profile -> show home
                if isAuthenticated && isProfileComplete {
                    self?.isLocked = false
                } else {
                    self?.isLocked = true
                }
            }
            .store(in: &cancellables)
    }

    @ViewBuilder
    func rootView() -> some View {
        if isCheckingAuth {
            // Show loading screen while checking authentication
            ZStack {
                Color.Brand.primary.opacity(0.06)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color.Brand.primary)
                    
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
        } else if isLocked {
            LoginView()
        } else {
            RootTabView()
        }
    }
}
