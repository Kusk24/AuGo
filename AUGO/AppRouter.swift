// AppRouter.swift
import SwiftUI
import Combine

final class AppRouter: ObservableObject {
    @Published var isLocked: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {}
    
    func observeAuthState(authManager: AuthenticationManager) {
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
        if isLocked {
            LoginView()
        } else {
            RootTabView()
        }
    }
}
