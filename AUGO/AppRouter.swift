// AppRouter.swift
import SwiftUI
import Combine

final class AppRouter: ObservableObject {
    // show lock first; we can later hook Face ID here
    @Published var isLocked: Bool = true

    @ViewBuilder
    func rootView() -> some View {
        if isLocked {
            LockScreenView()
        } else {
            RootTabView()
        }
    }
}
