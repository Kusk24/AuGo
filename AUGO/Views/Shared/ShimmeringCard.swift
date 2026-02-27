import SwiftUI
import CoreMotion
import Combine

struct HolographicCaptureCard: View {
    let title: String
    let subtitle: String
    let descriptionText: String?
    let rarity: String?
    let imageURL: URL?
    let coinText: String
    let pointsText: String
    let cardHeight: CGFloat?

    @State private var shimmerOffset: CGFloat = -260
    @State private var dragOffset: CGSize = .zero
    @State private var isFloating = false
    @StateObject private var tiltController = DeviceTiltController()

    init(
        title: String,
        subtitle: String,
        descriptionText: String? = nil,
        rarity: String?,
        imageURL: URL?,
        coinText: String,
        pointsText: String,
        cardHeight: CGFloat? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.descriptionText = descriptionText
        self.rarity = rarity
        self.imageURL = imageURL
        self.coinText = coinText
        self.pointsText = pointsText
        self.cardHeight = cardHeight
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        ZStack {
            cardShape
                .fill(
                    LinearGradient(
                        colors: rarityGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    if let rarity, !rarity.isEmpty {
                        Text(rarity)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(rarityBadgeColor.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }

                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)

                if let descriptionText, !descriptionText.isEmpty {
                    Text(descriptionText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.84))
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.vertical, 2)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                    if let imageURL {
                        CachedRemoteImage(url: imageURL, cacheKey: imageURL.absoluteString) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                        } placeholder: {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(height: 138)

                HStack(spacing: 12) {
                    statChip(icon: "bitcoinsign.circle.fill", text: coinText)
                    statChip(icon: "star.fill", text: pointsText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.42), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 110)
                .rotationEffect(.degrees(18))
                .offset(x: shimmerOffset)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .frame(height: resolvedCardHeight)
        .clipShape(cardShape)
        .overlay(
            cardShape
                .stroke(Color.white.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: Color.cyan.opacity(0.18), radius: 14, y: 7)
        .shadow(color: Color.pink.opacity(0.16), radius: 10, y: 4)
        .offset(x: hoverOffset.width, y: hoverOffset.height + (isFloating ? -4 : 4))
        .rotation3DEffect(.degrees(Double(totalTilt.height / 13)), axis: (x: -1, y: 0, z: 0))
        .rotation3DEffect(.degrees(Double(totalTilt.width / 13)), axis: (x: 0, y: 1, z: 0))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragOffset = CGSize(width: value.translation.width * 0.45, height: value.translation.height * 0.45)
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                        dragOffset = .zero
                    }
                }
        )
        .onAppear {
            shimmerOffset = -260
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                shimmerOffset = 260
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isFloating = true
            }
            tiltController.start()
        }
        .onDisappear {
            tiltController.stop()
        }
    }

    private var totalTilt: CGSize {
        CGSize(
            width: dragOffset.width - CGFloat(tiltController.roll) * 30.24,
            height: dragOffset.height + CGFloat(tiltController.pitch) * 30.24
        )
    }

    private var hoverOffset: CGSize {
        CGSize(
            width: -CGFloat(tiltController.roll) * 15.84,
            height: -CGFloat(tiltController.pitch) * 12.96
        )
    }

    private var resolvedCardHeight: CGFloat {
        if let cardHeight {
            return cardHeight
        }
        let desc = descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !desc.isEmpty else { return 360 }
        let estimatedLines = max(2, Int(ceil(Double(desc.count) / 38.0)))
        let extraLines = max(0, estimatedLines - 2)
        return 360 + CGFloat(min(extraLines, 12)) * 16
    }

    private var rarityGradientColors: [Color] {
        switch normalizedRarity {
        case "common":
            return [Color(red: 0.30, green: 0.35, blue: 0.50), Color(red: 0.38, green: 0.45, blue: 0.60), Color(red: 0.50, green: 0.58, blue: 0.70)]
        case "uncommon":
            return [Color(red: 0.10, green: 0.45, blue: 0.28), Color(red: 0.16, green: 0.58, blue: 0.38), Color(red: 0.28, green: 0.70, blue: 0.46)]
        case "rare":
            return [Color(red: 0.12, green: 0.30, blue: 0.74), Color(red: 0.22, green: 0.42, blue: 0.85), Color(red: 0.32, green: 0.56, blue: 0.95)]
        case "ultra rare":
            return [Color(red: 0.16, green: 0.32, blue: 0.84), Color(red: 0.43, green: 0.17, blue: 0.82), Color(red: 0.98, green: 0.24, blue: 0.76)]
        case "legendary":
            return [Color(red: 0.64, green: 0.31, blue: 0.06), Color(red: 0.84, green: 0.45, blue: 0.12), Color(red: 0.97, green: 0.65, blue: 0.18)]
        default:
            return [Color(red: 0.16, green: 0.32, blue: 0.84), Color(red: 0.43, green: 0.17, blue: 0.82), Color(red: 0.98, green: 0.24, blue: 0.76)]
        }
    }

    private var rarityBadgeColor: Color {
        switch normalizedRarity {
        case "common":
            return Color(red: 0.70, green: 0.75, blue: 0.85)
        case "uncommon":
            return Color(red: 0.35, green: 0.86, blue: 0.52)
        case "rare":
            return Color(red: 0.35, green: 0.62, blue: 0.98)
        case "ultra rare":
            return Color(red: 0.85, green: 0.45, blue: 0.98)
        case "legendary":
            return Color(red: 0.98, green: 0.72, blue: 0.35)
        default:
            return Color.white.opacity(0.8)
        }
    }

    private var normalizedRarity: String {
        rarity?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
    }
}

private final class DeviceTiltController: ObservableObject {
    @Published var roll: Double = 0
    @Published var pitch: Double = 0

    private let motionManager = CMMotionManager()
    private var baselineRoll: Double?
    private var baselinePitch: Double?
    private let filterAlpha = 0.18

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        baselineRoll = nil
        baselinePitch = nil
        roll = 0
        pitch = 0
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let rawRoll = max(-1.1, min(1.1, motion.attitude.roll))
            let rawPitch = max(-1.1, min(1.1, motion.attitude.pitch))

            // Calibrate neutral pose when device is not flat on a table.
            // This makes the "rest position" match upright phone usage.
            if self.baselineRoll == nil || self.baselinePitch == nil {
                let isNearFlat = abs(motion.gravity.z) > 0.78
                guard !isNearFlat else { return }
                self.baselineRoll = rawRoll
                self.baselinePitch = rawPitch
                return
            }

            let deltaRoll = rawRoll - (self.baselineRoll ?? 0)
            let deltaPitch = rawPitch - (self.baselinePitch ?? 0)
            let clampedRoll = max(-0.9, min(0.9, deltaRoll))
            let clampedPitch = max(-0.9, min(0.9, deltaPitch))

            // Low-pass filter for smoother left/right and up/down movement.
            self.roll = (self.roll * (1 - self.filterAlpha)) + (clampedRoll * self.filterAlpha)
            self.pitch = (self.pitch * (1 - self.filterAlpha)) + (clampedPitch * self.filterAlpha)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        baselineRoll = nil
        baselinePitch = nil
        roll = 0
        pitch = 0
    }
}
