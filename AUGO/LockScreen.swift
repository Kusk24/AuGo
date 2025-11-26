// LockScreenView.swift
import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ZStack {
            Color.Brand.primary.opacity(0.06)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 70))
                    .foregroundColor(Color.Brand.primary)

                Text("AUGO")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color.Brand.primary)

                Button {
                    // For now just unlock; later replace with Face ID flow
                    router.isLocked = false
                } label: {
                    Text("Unlock")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(Color.Brand.primary)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }

                Spacer()
            }
            .padding()
        }
    }
}
