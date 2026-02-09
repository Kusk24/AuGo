import SwiftUI

struct ARCameraView: View {
    var body: some View {
        ZStack {
            Image("ARBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                // Top text – push down a bit
                Text("You found Foxy!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.Brand.coin)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 70)

                Spacer()

                // Foxy in the middle
                Image("Foxy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 6)

                Spacer()

                // Bottom text – pulled up from bottom
                Text("Tap to collect it!")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color.Brand.coin)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: -1)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 70)
            }
        }
    }
}
