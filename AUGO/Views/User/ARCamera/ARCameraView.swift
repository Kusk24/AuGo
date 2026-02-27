import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Combine
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

private enum ARContentMode: String, CaseIterable, Identifiable {
    case character = "Character"
    case posts = "Posts"

    var id: String { rawValue }
}

struct ARCameraView: View {
    @StateObject private var viewModel = ARCameraViewModel()

    var body: some View {
        ZStack {
            ARRealityContainerView(
                modelEntity: viewModel.modelEntity,
                shouldRenderModel: viewModel.contentMode == .character && viewModel.canRenderModel,
                renderSpawnID: viewModel.renderSpawnID,
                characterScale: viewModel.characterVisualScale,
                nearbyPosts: viewModel.shouldRenderPostOverlays ? viewModel.nearbyPosts : [],
                nearbyAnnouncements: viewModel.shouldRenderPostOverlays ? viewModel.nearbyAnnouncements : [],
                onAnnouncementLike: { announcementID in
                    viewModel.reactToAnnouncement(announcementID: announcementID, reaction: "like")
                },
                onAnnouncementDislike: { announcementID in
                    viewModel.reactToAnnouncement(announcementID: announcementID, reaction: "dislike")
                },
                onCapture: {
                    viewModel.captureCurrentSpawn()
                }
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Picker("", selection: $viewModel.contentMode) {
                    ForEach(ARContentMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.contentMode == .character {
                    Button {
                        viewModel.togglePostsOverlayInCharacter()
                    } label: {
                        Text(viewModel.showPostsInCharacter ? "Hide Post Overlay" : "Show Post Overlay")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.16))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text(viewModel.titleText)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundColor(.white)

                if viewModel.contentMode == .character {
                    Text(viewModel.characterRangeText)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                }

                if let distanceText = viewModel.distanceText {
                    Text(distanceText)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                }

                if let rewardInfoText = viewModel.rewardInfoText {
                    Text(rewardInfoText)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(viewModel.contentMode == .posts ? .white : Color.Brand.coin)
                }

                if viewModel.contentMode == .character && viewModel.canRenderModel {
                    Text(viewModel.catchInstructionText)
                        .font(.footnote)
                        .foregroundColor(Color.Brand.coin)
                }
            }
            .padding(12)
            .background(.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.red.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 20)
            }

            if let celebration = viewModel.captureCelebration {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.dismissCaptureCelebration()
                    }

                GeometryReader { proxy in
                    let cardMaxWidth = min(360, proxy.size.width - 36)
                    let maxCardRegionHeight = min(proxy.size.height * 0.72, 640)

                    VStack(spacing: 12) {
                        ScrollView(showsIndicators: false) {
                            HolographicCaptureCard(
                                title: celebration.title,
                                subtitle: celebration.subtitle,
                                descriptionText: celebration.descriptionText,
                                rarity: celebration.rarity,
                                imageURL: celebration.imageURL,
                                coinText: celebration.coinText,
                                pointsText: celebration.pointsText
                            )
                            .frame(maxWidth: cardMaxWidth)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                        }
                        .frame(maxHeight: maxCardRegionHeight)

                        Button("Close") {
                            viewModel.dismissCaptureCelebration()
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.captureCelebration?.id)
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.contentMode) { _, mode in
            viewModel.applyContentMode(mode)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

private struct ARRealityContainerView: UIViewRepresentable {
    let modelEntity: ModelEntity?
    let shouldRenderModel: Bool
    let renderSpawnID: String?
    let characterScale: CGFloat
    let nearbyPosts: [ARNearbyPost]
    let nearbyAnnouncements: [ARNearbyAnnouncement]
    let onAnnouncementLike: (String) -> Void
    let onAnnouncementDislike: (String) -> Void
    let onCapture: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        configuration.environmentTexturing = .automatic

        arView.automaticallyConfigureSession = false
        arView.session.run(configuration)

        context.coordinator.attach(to: arView)
        return arView
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.detach(from: uiView)
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.onCapture = onCapture
        context.coordinator.onAnnouncementLike = onAnnouncementLike
        context.coordinator.onAnnouncementDislike = onAnnouncementDislike
        context.coordinator.updateFloatingPosts(nearbyPosts)
        context.coordinator.updateFloatingAnnouncements(nearbyAnnouncements)
        context.coordinator.updateCharacterScale(Float(characterScale))

        guard shouldRenderModel, let modelEntity else {
            context.coordinator.clearModelIfNeeded()
            return
        }

        context.coordinator.render(modelEntity: modelEntity, renderSpawnID: renderSpawnID)
    }

    final class Coordinator: NSObject {
        private weak var arView: ARView?
        private var anchorEntity: AnchorEntity?
        private weak var currentModelEntity: ModelEntity?
        private weak var tapGestureRecognizer: UITapGestureRecognizer?
        private var currentSpawnID: String?
        private var baseCharacterScale: SIMD3<Float>?
        private var postAnchors: [String: AnchorEntity] = [:]
        private var postCards: [String: UIHostingController<ARNearbyPostCard>] = [:]
        private var postPriority: [String: Int] = [:]
        private var announcementAnchors: [String: AnchorEntity] = [:]
        private var announcementCards: [String: UIHostingController<ARNearbyAnnouncementCard>] = [:]
        private var announcementPriority: [String: Int] = [:]
        private var postLayoutSeed: simd_float4x4?
        private var smoothedCardFrames: [String: CGRect] = [:]
        private var displayLink: CADisplayLink?
        private let floatingStartTime = CACurrentMediaTime()
        private let postFloatAmplitude: CGFloat = 13.0
        private let postFloatFrequencyHz: Double = 0.595
        var onAnnouncementLike: (String) -> Void = { _ in }
        var onAnnouncementDislike: (String) -> Void = { _ in }
        var onCapture: () -> Void

        init(onCapture: @escaping () -> Void) {
            self.onCapture = onCapture
        }

        func attach(to arView: ARView) {
            self.arView = arView
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tap)
            tapGestureRecognizer = tap
            startDisplayLink()
        }

        func detach(from arView: ARView) {
            stopDisplayLink()
            if let tapGestureRecognizer {
                arView.removeGestureRecognizer(tapGestureRecognizer)
                self.tapGestureRecognizer = nil
            }
            clearModelIfNeeded()
            postCards.values.forEach { $0.view.removeFromSuperview() }
            postCards.removeAll()
            postAnchors.values.forEach { $0.removeFromParent() }
            postAnchors.removeAll()
            announcementCards.values.forEach { $0.view.removeFromSuperview() }
            announcementCards.removeAll()
            announcementAnchors.values.forEach { $0.removeFromParent() }
            announcementAnchors.removeAll()
            smoothedCardFrames.removeAll()
            arView.session.pause()
            self.arView = nil
        }

        func clearModelIfNeeded() {
            currentModelEntity = nil
            currentSpawnID = nil
            baseCharacterScale = nil
            anchorEntity?.removeFromParent()
            anchorEntity = nil
        }

        func updateFloatingPosts(_ posts: [ARNearbyPost]) {
            guard let arView else { return }
            postPriority = Dictionary(uniqueKeysWithValues: posts.enumerated().map { ($0.element.id, $0.offset) })
            if postLayoutSeed == nil {
                postLayoutSeed = arView.cameraTransform.matrix
            }

            let activeIDs = Set(posts.map(\.id))
            for existingID in postAnchors.keys where !activeIDs.contains(existingID) {
                postAnchors[existingID]?.removeFromParent()
                postAnchors.removeValue(forKey: existingID)
                smoothedCardFrames.removeValue(forKey: existingID)

                postCards[existingID]?.view.removeFromSuperview()
                postCards.removeValue(forKey: existingID)
            }
            if postAnchors.isEmpty && announcementAnchors.isEmpty {
                postLayoutSeed = arView.cameraTransform.matrix
            }

            for (index, post) in posts.enumerated() {
                if let host = postCards[post.id] {
                    host.rootView = ARNearbyPostCard(post: post)
                    continue
                }

                let anchor = AnchorEntity(world: floatingPostPosition(index: index, total: posts.count, arView: arView))
                arView.scene.addAnchor(anchor)
                postAnchors[post.id] = anchor

                let host = UIHostingController(rootView: ARNearbyPostCard(post: post))
                host.view.backgroundColor = .clear
                host.view.frame = CGRect(x: 0, y: 0, width: 230, height: 180)
                arView.addSubview(host.view)
                postCards[post.id] = host
            }

            updateFloatingPostScreenPositions()
        }

        func updateFloatingAnnouncements(_ announcements: [ARNearbyAnnouncement]) {
            guard let arView else { return }
            let baseIndex = postAnchors.count
            announcementPriority = Dictionary(uniqueKeysWithValues: announcements.enumerated().map { ($0.element.id, baseIndex + $0.offset) })
            if postLayoutSeed == nil {
                postLayoutSeed = arView.cameraTransform.matrix
            }

            let activeIDs = Set(announcements.map(\.id))
            for existingID in announcementAnchors.keys where !activeIDs.contains(existingID) {
                announcementAnchors[existingID]?.removeFromParent()
                announcementAnchors.removeValue(forKey: existingID)
                smoothedCardFrames.removeValue(forKey: "announcement_\(existingID)")

                announcementCards[existingID]?.view.removeFromSuperview()
                announcementCards.removeValue(forKey: existingID)
            }
            if postAnchors.isEmpty && announcementAnchors.isEmpty {
                postLayoutSeed = arView.cameraTransform.matrix
            }

            let total = max(announcements.count + postAnchors.count, 1)
            for (index, announcement) in announcements.enumerated() {
                if let host = announcementCards[announcement.id] {
                    host.rootView = ARNearbyAnnouncementCard(
                        announcement: announcement,
                        onLike: { self.onAnnouncementLike(announcement.id) },
                        onDislike: { self.onAnnouncementDislike(announcement.id) }
                    )
                    continue
                }

                let anchor = AnchorEntity(world: floatingPostPosition(index: index + postAnchors.count, total: total, arView: arView))
                arView.scene.addAnchor(anchor)
                announcementAnchors[announcement.id] = anchor

                let host = UIHostingController(
                    rootView: ARNearbyAnnouncementCard(
                        announcement: announcement,
                        onLike: { self.onAnnouncementLike(announcement.id) },
                        onDislike: { self.onAnnouncementDislike(announcement.id) }
                    )
                )
                host.view.backgroundColor = .clear
                host.view.frame = CGRect(x: 0, y: 0, width: 240, height: 210)
                arView.addSubview(host.view)
                announcementCards[announcement.id] = host
            }

            updateFloatingPostScreenPositions()
        }

        private func floatingPostPosition(index: Int, total: Int, arView: ARView) -> SIMD3<Float> {
            let seed = postLayoutSeed ?? arView.cameraTransform.matrix
            let cameraPosition = SIMD3<Float>(seed.columns.3.x, seed.columns.3.y, seed.columns.3.z)
            let forward = -SIMD3<Float>(seed.columns.2.x, seed.columns.2.y, seed.columns.2.z)
            let right = SIMD3<Float>(seed.columns.0.x, seed.columns.0.y, seed.columns.0.z)
            let up = SIMD3<Float>(seed.columns.1.x, seed.columns.1.y, seed.columns.1.z)

            let normalizedForward = simd_normalize(forward)
            let normalizedRight = simd_normalize(right)
            let normalizedUp = simd_normalize(up)

            let count = max(total, 1)
            let arc: Float = count <= 3 ? 0.9 : min(2.2, 0.9 + Float(count - 3) * 0.18)
            let normalizedIndex = count == 1 ? 0 : Float(index) / Float(count - 1)
            let azimuth = -arc / 2 + (arc * normalizedIndex)
            let ring = Float(index / 5)

            let depth: Float = 1.45 + ring * 0.35
            let horizontalOffset = tan(azimuth) * depth
            // Start around eye/chest level so standing straight can see cards.
            let baseVertical: Float = -0.02
            // For dense sets, distribute posts up/down so users can discover by scanning.
            let verticalWave = sin(Float(index) * 1.3) * (count > 4 ? 0.42 : 0.2)
            let verticalOffset = baseVertical + verticalWave - ring * 0.08

            return cameraPosition
                + normalizedForward * depth
                + normalizedRight * horizontalOffset
                + normalizedUp * verticalOffset
        }

        private func startDisplayLink() {
            displayLink?.invalidate()
            let link = CADisplayLink(target: self, selector: #selector(onDisplayTick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        private func stopDisplayLink() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc
        private func onDisplayTick() {
            updateFloatingPostScreenPositions()
        }

        private func updateFloatingPostScreenPositions() {
            guard let arView else { return }

            let t = CACurrentMediaTime() - floatingStartTime
            let topReserved = min(240, arView.bounds.height * 0.26)
            let bottomReserved = max(130, arView.safeAreaInsets.bottom + 96)
            let bounds = usableCardBounds(in: arView.bounds, topReserved: topReserved, bottomReserved: bottomReserved)
            let visibilityBounds = arView.bounds.insetBy(dx: 12, dy: 12)
            let cameraTransform = arView.cameraTransform.matrix
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            let cameraForward = simd_normalize(-SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z))

            let sortedPostIDs = postAnchors.keys.sorted {
                (postPriority[$0] ?? .max) < (postPriority[$1] ?? .max)
            }
            let sortedAnnouncementIDs = announcementAnchors.keys.sorted {
                (announcementPriority[$0] ?? .max) < (announcementPriority[$1] ?? .max)
            }

            var preferredFrames: [(id: String, frame: CGRect)] = []
            for id in sortedPostIDs {
                guard let anchor = postAnchors[id] else { continue }
                guard let host = postCards[id] else { continue }
                let worldPosition = anchor.position(relativeTo: nil)
                let toPost = worldPosition - cameraPosition
                let distance = simd_length(toPost)
                guard distance > 0.001 else {
                    host.view.isHidden = true
                    continue
                }
                // Hide posts that are outside the current view direction.
                let facing = simd_dot(simd_normalize(toPost), cameraForward)
                if facing < 0.25 {
                    host.view.isHidden = true
                    continue
                }
                guard let projected = arView.project(worldPosition) else {
                    host.view.isHidden = true
                    continue
                }
                // Do not pin off-screen cards; hide until user looks toward them.
                if !visibilityBounds.contains(CGPoint(x: projected.x, y: projected.y)) {
                    host.view.isHidden = true
                    continue
                }

                let angularVelocity = postFloatFrequencyHz * 2.0 * Double.pi
                let bob = CGFloat(sin(t * angularVelocity) * postFloatAmplitude)
                let size = host.view.bounds.size == .zero ? CGSize(width: 230, height: 180) : host.view.bounds.size
                let frame = CGRect(
                    x: projected.x - (size.width / 2),
                    y: projected.y + bob - (size.height / 2),
                    width: size.width,
                    height: size.height
                )
                preferredFrames.append((id: id, frame: frame))
            }
            for id in sortedAnnouncementIDs {
                guard let anchor = announcementAnchors[id] else { continue }
                guard let host = announcementCards[id] else { continue }
                let worldPosition = anchor.position(relativeTo: nil)
                let toPost = worldPosition - cameraPosition
                let distance = simd_length(toPost)
                guard distance > 0.001 else {
                    host.view.isHidden = true
                    continue
                }
                let facing = simd_dot(simd_normalize(toPost), cameraForward)
                if facing < 0.25 {
                    host.view.isHidden = true
                    continue
                }
                guard let projected = arView.project(worldPosition) else {
                    host.view.isHidden = true
                    continue
                }
                if !visibilityBounds.contains(CGPoint(x: projected.x, y: projected.y)) {
                    host.view.isHidden = true
                    continue
                }

                let angularVelocity = postFloatFrequencyHz * 2.0 * Double.pi
                let bob = CGFloat(sin(t * angularVelocity) * postFloatAmplitude)
                let size = host.view.bounds.size == .zero ? CGSize(width: 240, height: 210) : host.view.bounds.size
                let frame = CGRect(
                    x: projected.x - (size.width / 2),
                    y: projected.y + bob - (size.height / 2),
                    width: size.width,
                    height: size.height
                )
                preferredFrames.append((id: "announcement_\(id)", frame: frame))
            }

            // Resolve collisions aggressively so cards remain readable even in dense clusters.
            let resolvedFrames = separateOverlaps(preferredFrames, in: bounds)

            for (rank, item) in resolvedFrames.enumerated() {
                if let host = postCards[item.id] {
                    host.view.isHidden = false
                    let previous = smoothedCardFrames[item.id] ?? item.frame
                    let smoothed = CGRect(
                        x: previous.origin.x + (item.frame.origin.x - previous.origin.x) * 0.32,
                        y: previous.origin.y + (item.frame.origin.y - previous.origin.y) * 0.5,
                        width: item.frame.width,
                        height: item.frame.height
                    )
                    let clamped = clamp(smoothed, to: bounds)
                    smoothedCardFrames[item.id] = clamped
                    host.view.frame = clamped
                    host.view.alpha = rank < 3 ? 1.0 : 0.92
                    continue
                }
                guard item.id.hasPrefix("announcement_") else { continue }
                let announcementID = String(item.id.dropFirst("announcement_".count))
                guard let host = announcementCards[announcementID] else { continue }
                host.view.isHidden = false
                let previous = smoothedCardFrames[item.id] ?? item.frame
                let smoothed = CGRect(
                    x: previous.origin.x + (item.frame.origin.x - previous.origin.x) * 0.32,
                    y: previous.origin.y + (item.frame.origin.y - previous.origin.y) * 0.5,
                    width: item.frame.width,
                    height: item.frame.height
                )
                let clamped = clamp(smoothed, to: bounds)
                smoothedCardFrames[item.id] = clamped
                host.view.frame = clamped
                host.view.alpha = rank < 3 ? 1.0 : 0.92
            }

            // Hide cards that were not visible in this tick.
            let visibleIDs = Set(resolvedFrames.map(\.id))
            for (id, host) in postCards where !visibleIDs.contains(id) {
                host.view.isHidden = true
            }
            for (id, host) in announcementCards where !visibleIDs.contains("announcement_\(id)") {
                host.view.isHidden = true
            }
        }

        private func usableCardBounds(in rect: CGRect, topReserved: CGFloat, bottomReserved: CGFloat) -> CGRect {
            let width = max(rect.width - 16, 1)
            let height = max(rect.height - topReserved - bottomReserved, 1)
            return CGRect(x: rect.minX + 8, y: rect.minY + topReserved, width: width, height: height)
        }

        private func separateOverlaps(_ input: [(id: String, frame: CGRect)], in bounds: CGRect) -> [(id: String, frame: CGRect)] {
            guard input.count > 1 else { return input }
            var output = input
            let minimumSpacing: CGFloat = 22

            for _ in 0..<14 {
                var movedAny = false

                for i in 0..<output.count {
                    for j in 0..<i {
                        let frameA = output[i].frame
                        let frameB = output[j].frame
                        let expandedA = frameA.insetBy(dx: -minimumSpacing, dy: -minimumSpacing)
                        let expandedB = frameB.insetBy(dx: -minimumSpacing, dy: -minimumSpacing)
                        let overlap = expandedA.intersection(expandedB)
                        guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { continue }

                        let centerA = CGPoint(x: frameA.midX, y: frameA.midY)
                        let centerB = CGPoint(x: frameB.midX, y: frameB.midY)
                        var dx = centerA.x - centerB.x
                        var dy = centerA.y - centerB.y
                        if abs(dx) < 0.01 && abs(dy) < 0.01 {
                            dx = (i % 2 == 0) ? 1 : -1
                            dy = (j % 2 == 0) ? 1 : -1
                        }

                        let length = max(sqrt(dx * dx + dy * dy), 0.001)
                        let push = min(max(overlap.width, overlap.height) * 0.5, 30)
                        let offsetX = (dx / length) * push
                        let offsetY = (dy / length) * push

                        var movedFrame = frameA
                        movedFrame.origin.x += offsetX
                        movedFrame.origin.y += offsetY
                        movedFrame = clamp(movedFrame, to: bounds)

                        if movedFrame != output[i].frame {
                            output[i].frame = movedFrame
                            movedAny = true
                        }
                    }
                }

                if !movedAny {
                    break
                }
            }

            return output
        }

        private func clamp(_ frame: CGRect, to bounds: CGRect) -> CGRect {
            var clamped = frame
            clamped.origin.x = min(max(clamped.origin.x, bounds.minX), bounds.maxX - clamped.width)
            clamped.origin.y = min(max(clamped.origin.y, bounds.minY), bounds.maxY - clamped.height)
            return clamped
        }

        func render(modelEntity: ModelEntity, renderSpawnID: String?) {
            guard let arView else { return }
            guard let renderSpawnID else { return }

            if currentSpawnID == renderSpawnID {
                return
            }

            clearModelIfNeeded()

            let cloned = modelEntity.clone(recursive: true)
            cloned.generateCollisionShapes(recursive: true)
            normalizeModelScale(cloned, targetHeight: 0.5)

            let cameraTransform = arView.cameraTransform.matrix
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            let forward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
            let normalizedForward = simd_normalize(forward)
            let spawnPosition = cameraPosition + normalizedForward * 2.0

            let anchor = AnchorEntity(world: spawnPosition)
            anchor.addChild(cloned)
            arView.scene.addAnchor(anchor)

            anchorEntity = anchor
            currentModelEntity = cloned
            currentSpawnID = renderSpawnID
            baseCharacterScale = cloned.scale
        }

        func updateCharacterScale(_ scaleMultiplier: Float) {
            guard let currentModelEntity, let baseCharacterScale else { return }
            let clamped = min(max(scaleMultiplier, 0.7), 1.8)
            currentModelEntity.scale = baseCharacterScale * SIMD3<Float>(repeating: clamped)
        }

        @objc
        private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView, let currentModelEntity else { return }
            let location = gesture.location(in: arView)
            if let tapped = arView.entity(at: location), isSameTree(lhs: tapped, rhs: currentModelEntity) {
                onCapture()
            }
        }

        private func normalizeModelScale(_ entity: Entity, targetHeight: Float) {
            let bounds = entity.visualBounds(relativeTo: nil)
            let height = bounds.extents.y
            guard height > 0.0001 else { return }

            let rawScale = targetHeight / height
            let clampedScale = min(max(rawScale, 0.05), 2.0)
            entity.scale *= SIMD3<Float>(repeating: clampedScale)
        }

        private func isSameTree(lhs: Entity, rhs: Entity) -> Bool {
            if lhs == rhs {
                return true
            }

            var current: Entity? = lhs
            while let node = current {
                if node == rhs {
                    return true
                }
                current = node.parent
            }

            current = rhs
            while let node = current {
                if node == lhs {
                    return true
                }
                current = node.parent
            }

            return false
        }

        deinit {
            stopDisplayLink()
            postCards.values.forEach { $0.view.removeFromSuperview() }
            postCards.removeAll()
            postAnchors.values.forEach { $0.removeFromParent() }
            postAnchors.removeAll()
            announcementCards.values.forEach { $0.view.removeFromSuperview() }
            announcementCards.removeAll()
            announcementAnchors.values.forEach { $0.removeFromParent() }
            announcementAnchors.removeAll()
        }
    }
}

private final class ARCameraViewModel: ObservableObject {
    struct ARAdminConfiguration {
        let postVisibleRangeMeters: Double
        let postVisibilityDurationHours: Int

        static let `default` = ARAdminConfiguration(
            postVisibleRangeMeters: 50,
            postVisibilityDurationHours: 24
        )
    }

    @Published var contentMode: ARContentMode = .character
    @Published var titleText = "AR Hunt"
    @Published var statusText = "Loading nearby AR spawn..."
    @Published var distanceText: String?
    @Published var errorText: String?
    @Published var canRenderModel = false
    @Published var modelEntity: ModelEntity?
    @Published var renderSpawnID: String?
    @Published var characterVisualScale: CGFloat = 1.0
    @Published var rewardInfoText: String?
    @Published var catchInstructionText = "Get inside catch radius to start combo"
    @Published var characterRangeText = "Character range: 100 m"
    @Published var nearbyPosts: [ARNearbyPost] = []
    @Published var nearbyAnnouncements: [ARNearbyAnnouncement] = []
    @Published var showPostsInCharacter = false
    @Published var captureCelebration: ARCaptureCelebration?

    private let locationManager = LocationManager()
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    private var activeSpawn: ARSpawn?
    private var didStart = false
    private var loadSpawnTask: Task<Void, Never>?
    private var distanceMonitorTask: Task<Void, Never>?
    private var nearbyPostsMonitorTask: Task<Void, Never>?
    private var userCaptureProgress: [String: ARCaptureProgress] = [:]
    private var smoothedDistanceMeters: Double?
    private var comboHits = 0
    private var lastHitAt: Date?
    private let comboRequiredHits = 3
    private let comboWindowSeconds: TimeInterval = 2.0
    private var isCaptureProcessing = false
    private let maxRenderableHorizontalAccuracy: CLLocationAccuracy = 30
    private let maxCatchHorizontalAccuracy: CLLocationAccuracy = 15
    private var arAdminConfigCache: ARAdminConfiguration = .default
    private var lastARAdminConfigFetch: Date?
    private var photoURLCache: [String: URL] = [:]
    private var reactingAnnouncementIDs: Set<String> = []
    private var announcementRewardClaimedMap: [String: Bool] = [:]
    private var announcementUserReactionMap: [String: String] = [:]

    var shouldRenderPostOverlays: Bool {
        contentMode == .posts || (contentMode == .character && showPostsInCharacter)
    }

    func onAppear() {
        guard !didStart else { return }
        didStart = true

        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        applyContentMode(contentMode)
    }

    func onDisappear() {
        locationManager.stopUpdatingLocation()
        loadSpawnTask?.cancel()
        distanceMonitorTask?.cancel()
        nearbyPostsMonitorTask?.cancel()
        didStart = false
    }

    func applyContentMode(_ mode: ARContentMode) {
        errorText = nil
        switch mode {
        case .character:
            titleText = "Nearby Character"
            statusText = "Locating nearest character..."
            distanceText = nil
            rewardInfoText = nil
            characterRangeText = "Character range: 100 m"
            if showPostsInCharacter {
                startNearbyPostsMonitoring()
            } else {
                nearbyPostsMonitorTask?.cancel()
                nearbyPosts = []
                nearbyAnnouncements = []
            }
            smoothedDistanceMeters = nil
            loadSpawnTask?.cancel()
            loadSpawnTask = Task { @MainActor in
                await loadNearestSpawnAndAssetIfNeeded()
            }
        case .posts:
            Task { [weak self] in
                _ = await self?.loadARAdminConfiguration(forceRefresh: true)
            }
            loadSpawnTask?.cancel()
            distanceMonitorTask?.cancel()
            canRenderModel = false
            renderSpawnID = nil
            modelEntity = nil
            activeSpawn = nil
            rewardInfoText = "Nearest: none"
            distanceText = nil
            smoothedDistanceMeters = nil
            titleText = "Nearby Posts"
            statusText = "Posts in range: 0"
            catchInstructionText = ""
            startNearbyPostsMonitoring()
        }
    }

    func togglePostsOverlayInCharacter() {
        showPostsInCharacter.toggle()
        guard contentMode == .character else { return }
        if showPostsInCharacter {
            startNearbyPostsMonitoring()
        } else {
            nearbyPostsMonitorTask?.cancel()
            nearbyPosts = []
            nearbyAnnouncements = []
        }
    }

    func reactToAnnouncement(announcementID: String, reaction: String) {
        guard reaction == "like" || reaction == "dislike" else { return }
        guard let userID = auth.currentUser?.uid else {
            errorText = "Sign in to react to announcements."
            return
        }
        guard !reactingAnnouncementIDs.contains(announcementID) else { return }
        reactingAnnouncementIDs.insert(announcementID)

        Task { @MainActor in
            defer { reactingAnnouncementIDs.remove(announcementID) }
            do {
                let announcementManager = AnnouncementManager()
                let result = try await announcementManager.reactToAnnouncement(
                    announcementId: announcementID,
                    userId: userID,
                    reaction: reaction,
                    awardCoin: true
                )
                if let index = nearbyAnnouncements.firstIndex(where: { $0.id == announcementID }) {
                    nearbyAnnouncements[index].likeCount = result.likeCount
                    nearbyAnnouncements[index].dislikeCount = result.dislikeCount
                    nearbyAnnouncements[index].userReaction = result.reaction
                    if result.coinAwarded > 0 {
                        nearbyAnnouncements[index].rewardClaimed = true
                    }
                }
                if let reaction = result.reaction {
                    announcementUserReactionMap[announcementID] = reaction
                } else {
                    announcementUserReactionMap.removeValue(forKey: announcementID)
                }
                if result.coinAwarded > 0 {
                    statusText = String(format: "Reaction saved. +%.1f coins", result.coinAwarded)
                    announcementRewardClaimedMap[announcementID] = true
                } else {
                    statusText = "Reaction saved. Reward was already claimed."
                }
            } catch {
                errorText = "Failed reacting to announcement: \(error.localizedDescription)"
            }
        }
    }

    func captureCurrentSpawn() {
        guard let spawn = activeSpawn else { return }
        guard !isCaptureProcessing else { return }
        guard let location = locationManager.lastLocation else { return }
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= maxCatchHorizontalAccuracy else {
            statusText = String(format: "GPS too noisy (±%.0fm). Move to open sky.", max(location.horizontalAccuracy, 0))
            catchInstructionText = "Wait for better GPS to catch"
            return
        }

        switch eligibility(for: spawn, now: Date()) {
        case .limitReached(let limit):
            catchInstructionText = "Limit reached (\(limit)/\(limit))"
            statusText = "This character is fully captured"
            canRenderModel = false
            renderSpawnID = nil
            return
        case .cooldown(let availableAt):
            let relative = RelativeDateTimeFormatter().localizedString(for: availableAt, relativeTo: Date())
            catchInstructionText = "Next catch \(relative)"
            statusText = "Cooldown active"
            canRenderModel = false
            renderSpawnID = nil
            return
        case .available:
            break
        }

        guard let distance = distanceToSpawn(spawn), distance <= spawn.catchRadius else {
            comboHits = 0
            catchInstructionText = String(format: "Too far. Move within %.1f m to catch", spawn.catchRadius)
            statusText = String(format: "Move %.1f m closer for catch zone", max((distanceToSpawn(spawn) ?? spawn.catchRadius) - spawn.catchRadius, 0))
            return
        }

        let now = Date()
        if let lastHitAt, now.timeIntervalSince(lastHitAt) <= comboWindowSeconds {
            comboHits += 1
        } else {
            comboHits = 1
        }
        self.lastHitAt = now

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if comboHits < comboRequiredHits {
            catchInstructionText = "Combo \(comboHits)/\(comboRequiredHits) - tap quickly!"
            statusText = "Keep combo alive"
            return
        }

        comboHits = 0
        lastHitAt = nil
        isCaptureProcessing = true
        statusText = "Saving capture..."
        catchInstructionText = "Processing"

        Task { @MainActor in
            do {
                let result = try await persistCapture(for: spawn)
                userCaptureProgress[spawn.id] = ARCaptureProgress(count: result.newCount, lastCapturedAt: Date())
                statusText = "Captured \(spawn.title)! +\(formatCoins(spawn.coinValue)) coins, +\(spawn.pointValue) points"
                catchInstructionText = result.newCount >= spawn.catchableTime ? "Limit reached for this spawn" : "Captured! Ready again after cooldown"
                captureCelebration = ARCaptureCelebration(
                    title: spawn.title,
                    subtitle: "Captured \(result.newCount)/\(spawn.catchableTime)",
                    descriptionText: spawn.descriptionText,
                    rarity: spawn.rarity,
                    imageURL: storageMediaURL(from: spawn.preview),
                    coinText: "+\(formatCoins(spawn.coinValue))",
                    pointsText: "+\(spawn.pointValue) pts"
                )
                renderSpawnID = nil
                canRenderModel = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                try? await Task.sleep(nanoseconds: 900_000_000)
                await loadNearestSpawnAndAssetIfNeeded()
            } catch {
                if let arError = error as? ARCameraError {
                    switch arError {
                    case .captureLimitReached(let limit):
                        catchInstructionText = "Limit reached (\(limit)/\(limit))"
                        statusText = "No more catches for this spawn"
                    case .captureCooldown(let availableAt):
                        let relative = RelativeDateTimeFormatter().localizedString(for: availableAt, relativeTo: Date())
                        catchInstructionText = "Next catch \(relative)"
                        statusText = "Cooldown active"
                    default:
                        errorText = "Failed to capture: \(arError.localizedDescription)"
                        statusText = "Capture failed"
                    }
                } else {
                    errorText = "Failed to capture: \(error.localizedDescription)"
                    statusText = "Capture failed"
                }
            }
            isCaptureProcessing = false
        }
    }

    func dismissCaptureCelebration() {
        captureCelebration = nil
    }

    @MainActor
    private func loadNearestSpawnAndAssetIfNeeded() async {
        if Task.isCancelled { return }
        errorText = nil
        do {
            let spawn = try await fetchNearestActiveSpawn()
            if Task.isCancelled { return }
            activeSpawn = spawn
            titleText = spawn.title
            rewardInfoText = "Nearest: \(spawn.title) • +\(formatCoins(spawn.coinValue)) coins • +\(spawn.pointValue) points"
            characterRangeText = String(format: "Character range: %.0f m", spawn.revealRadius)

            let currentDistance = distanceToSpawn(spawn)
            if let currentDistance {
                distanceText = String(format: "Distance: %.1f m", currentDistance)
            } else {
                distanceText = "Waiting for GPS signal..."
            }

            modelEntity = try await loadModelEntity(from: spawn.assetPath)
            if Task.isCancelled { return }
            statusText = "Move closer to reveal AR object"

            startDistanceMonitoring()
            updateRenderEligibility()
        } catch is CancellationError {
            // Expected when quickly switching AR modes.
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Network request was canceled by mode switch.
            return
        } catch let arError as ARCameraError {
            switch arError {
            case .noCatchableSpawns:
                titleText = "AR Hunt"
                statusText = "No catchable AR characters right now"
                catchInstructionText = "Try again later"
                rewardInfoText = nil
                distanceText = nil
                characterRangeText = "Character range: 100 m"
                canRenderModel = false
                renderSpawnID = nil
            case .noActiveSpawns:
                titleText = "AR Hunt"
                statusText = "No active AR spawns"
                rewardInfoText = nil
                distanceText = nil
                characterRangeText = "Character range: 100 m"
                canRenderModel = false
                renderSpawnID = nil
            default:
                errorText = "Failed to load AR spawn: \(arError.localizedDescription)"
                statusText = "Unable to load AR content"
            }
        } catch {
            errorText = "Failed to load AR spawn: \(error.localizedDescription)"
            statusText = "Unable to load AR content"
        }
    }

    private func fetchNearestActiveSpawn() async throws -> ARSpawn {
        let snapshot = try await db.collection("ar_spawns")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        let spawns = snapshot.documents.flatMap { doc in
            ARSpawn.fromDocument(documentID: doc.documentID, data: doc.data())
        }

        guard !spawns.isEmpty else {
            throw ARCameraError.noActiveSpawns
        }

        userCaptureProgress = try await fetchUserCaptureProgress()
        let now = Date()
        let availableSpawns = spawns.filter {
            if case .available = eligibility(for: $0, now: now) {
                return true
            }
            return false
        }

        guard !availableSpawns.isEmpty else {
            throw ARCameraError.noCatchableSpawns
        }

        guard let userLocation = locationManager.lastLocation else {
            return availableSpawns[0]
        }

        let nearest = availableSpawns.min { lhs, rhs in
            let l = lhs.location.distance(from: userLocation)
            let r = rhs.location.distance(from: userLocation)
            return l < r
        }

        guard let nearest else {
            throw ARCameraError.noActiveSpawns
        }

        return nearest
    }

    private func distanceToSpawn(_ spawn: ARSpawn) -> CLLocationDistance? {
        guard let userLocation = locationManager.lastLocation else { return nil }
        let rawDistance = spawn.location.distance(from: userLocation)
        if smoothedDistanceMeters == nil {
            smoothedDistanceMeters = rawDistance
        } else if let current = smoothedDistanceMeters {
            // Exponential smoothing to reduce GPS oscillation.
            smoothedDistanceMeters = (current * 0.72) + (rawDistance * 0.28)
        }

        let accuracy = max(userLocation.horizontalAccuracy, 0)
        let accuracyPenalty = max(0, accuracy - 8) * 0.35
        return (smoothedDistanceMeters ?? rawDistance) + accuracyPenalty
    }

    private func updateRenderEligibility() {
        guard contentMode == .character else { return }
        guard let spawn = activeSpawn else {
            canRenderModel = false
            renderSpawnID = nil
            return
        }

        switch eligibility(for: spawn, now: Date()) {
        case .limitReached(let limit):
            canRenderModel = false
            renderSpawnID = nil
            statusText = "Capture limit reached (\(limit)/\(limit))"
            catchInstructionText = "This spawn is completed"
            rewardInfoText = nil
            return
        case .cooldown(let availableAt):
            canRenderModel = false
            renderSpawnID = nil
            let relative = RelativeDateTimeFormatter().localizedString(for: availableAt, relativeTo: Date())
            statusText = "Cooldown active"
            catchInstructionText = "Available \(relative)"
            rewardInfoText = "Nearest: \(spawn.title) • +\(formatCoins(spawn.coinValue)) coins • +\(spawn.pointValue) points"
            return
        case .available:
            break
        }

        guard let distance = distanceToSpawn(spawn) else {
            canRenderModel = false
            renderSpawnID = nil
            statusText = "Waiting for accurate location..."
            distanceText = "Waiting for GPS signal..."
            return
        }

        if let location = locationManager.lastLocation,
           location.horizontalAccuracy <= 0 || location.horizontalAccuracy > maxRenderableHorizontalAccuracy {
            canRenderModel = false
            renderSpawnID = nil
            characterVisualScale = 1.0
            statusText = String(format: "Improving GPS... current ±%.0fm", max(location.horizontalAccuracy, 0))
            distanceText = "Move to open sky for better accuracy"
            catchInstructionText = "Character hidden until GPS improves"
            return
        }

        distanceText = String(format: "Distance: %.1f m", distance)

        if distance <= spawn.revealRadius {
            canRenderModel = true
            renderSpawnID = spawn.id
            statusText = "Spawn unlocked"
            rewardInfoText = "Nearest: \(spawn.title) • +\(formatCoins(spawn.coinValue)) coins • +\(spawn.pointValue) points"
            characterVisualScale = characterScale(for: distance, spawn: spawn)
            if distance <= spawn.catchRadius {
                catchInstructionText = "Tap 3x quickly to catch (+\(formatCoins(spawn.coinValue)) coins, +\(spawn.pointValue) pts)"
            } else {
                let need = max(distance - spawn.catchRadius, 0)
                catchInstructionText = String(format: "Move %.1f m closer to start 3-hit combo", need)
            }
        } else {
            canRenderModel = false
            renderSpawnID = nil
            comboHits = 0
            lastHitAt = nil
            characterVisualScale = 1.0
            let remaining = max(distance - spawn.revealRadius, 0)
            statusText = String(format: "Move %.1f m closer to reveal", remaining)
            rewardInfoText = "Nearest: \(spawn.title) • +\(formatCoins(spawn.coinValue)) coins • +\(spawn.pointValue) points"
            catchInstructionText = "Hidden until reveal radius"
        }
    }

    private func startDistanceMonitoring() {
        distanceMonitorTask?.cancel()
        distanceMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    self?.updateRenderEligibility()
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func startNearbyPostsMonitoring() {
        nearbyPostsMonitorTask?.cancel()
        nearbyPostsMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshNearbyPosts()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    @MainActor
    private func refreshNearbyPosts() async {
        let adminConfig = await loadARAdminConfiguration()
        let visibleRange = max(1, adminConfig.postVisibleRangeMeters)
        let cutoffDate = Calendar.current.date(
            byAdding: .hour,
            value: -max(1, adminConfig.postVisibilityDurationHours),
            to: Date()
        ) ?? Date.distantPast

        guard let userLocation = locationManager.lastLocation else {
            nearbyPosts = []
            nearbyAnnouncements = []
            return
        }

        do {
            async let postSnapshotTask = db.collection("posts")
                .whereField("status", isEqualTo: "active")
                .limit(to: 60)
                .getDocuments()
            async let announcementSnapshotTask = db.collection("announcements")
                .limit(to: 60)
                .getDocuments()

            let (snapshot, announcementSnapshot) = try await (postSnapshotTask, announcementSnapshotTask)

            let mapped = snapshot.documents.compactMap { doc -> ARNearbyPost? in
                let data = doc.data()
                guard
                    let content = data["content"] as? String,
                    let lat = toDouble(data["latitude"]),
                    let lon = toDouble(data["longitude"])
                else { return nil }
                guard let createdAt = parsePostDate(data), createdAt >= cutoffDate else {
                    return nil
                }

                let likeCount = intValue(data["likeCount"])
                let dislikeCount = intValue(data["dislikeCount"])
                let category = postCategory(from: data["category"])
                let postLocation = CLLocation(latitude: lat, longitude: lon)
                let distance = postLocation.distance(from: userLocation)

                let photoPaths = data["photoPaths"] as? [String] ?? []
                let firstPath = photoPaths.first
                    ?? (data["photoPath"] as? String)
                    ?? (data["imagePath"] as? String)
                let firstPhotoURL = firstPath.flatMap(cachedStorageDownloadURL(for:))
                let emojiPin = (data["emojiPin"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return ARNearbyPost(
                    id: doc.documentID,
                    message: content,
                    category: category,
                    likeCount: likeCount,
                    dislikeCount: dislikeCount,
                    distanceMeters: distance,
                    firstPhotoURL: firstPhotoURL,
                    emojiPin: (emojiPin?.isEmpty == false) ? emojiPin : nil,
                    proximityScale: proximityScale(for: distance)
                )
            }

            nearbyPosts = mapped
                .filter { $0.distanceMeters <= visibleRange }
                .sorted { $0.distanceMeters < $1.distanceMeters }
                .prefix(8)
                .map { $0 }

            if let userID = auth.currentUser?.uid {
                do {
                    let userSnapshot = try await db.collection("users").document(userID).getDocument()
                    announcementRewardClaimedMap = userSnapshot.data()?["announcementReactionRewards"] as? [String: Bool] ?? [:]
                } catch {
                    announcementRewardClaimedMap = [:]
                }
                do {
                    let reactionSnapshot = try await db.collection("announcement_reactions")
                        .whereField("userId", isEqualTo: userID)
                        .limit(to: 200)
                        .getDocuments()
                    announcementUserReactionMap = Dictionary(
                        uniqueKeysWithValues: reactionSnapshot.documents.compactMap { doc in
                            let data = doc.data()
                            guard
                                let announcementID = data["announcementId"] as? String,
                                let reaction = data["reaction"] as? String
                            else { return nil }
                            return (announcementID, reaction)
                        }
                    )
                } catch {
                    announcementUserReactionMap = [:]
                }
            } else {
                announcementRewardClaimedMap = [:]
                announcementUserReactionMap = [:]
            }

            let now = Date()
            let mappedAnnouncements = announcementSnapshot.documents.compactMap { doc -> ARNearbyAnnouncement? in
                let data = doc.data()
                guard
                    let title = data["title"] as? String,
                    let body = data["body"] as? String,
                    let lat = toDouble(data["latitude"]),
                    let lon = toDouble(data["longitude"]),
                    let statusRaw = data["status"] as? String,
                    let status = AnnouncementStatus.fromFirestore(statusRaw)
                else { return nil }

                let startDate = (data["startDate"] as? Timestamp)?.dateValue()
                    ?? (data["createdAt"] as? Timestamp)?.dateValue()
                    ?? now
                let endDate = (data["endDate"] as? Timestamp)?.dateValue()
                    ?? Calendar.current.date(byAdding: .day, value: 1, to: startDate)
                    ?? startDate
                guard status == .active, startDate <= now, now <= endDate else {
                    return nil
                }

                let distance = CLLocation(latitude: lat, longitude: lon).distance(from: userLocation)
                let photoPaths = data["photoPaths"] as? [String] ?? []
                let firstPhotoURL = photoPaths.first.flatMap(cachedStorageDownloadURL(for:))
                let coinReward = (data["coinReward"] as? Double)
                    ?? (data["coinReward"] as? NSNumber)?.doubleValue
                    ?? 0.2

                return ARNearbyAnnouncement(
                    id: doc.documentID,
                    title: title,
                    body: body,
                    likeCount: intValue(data["likeCount"]),
                    dislikeCount: intValue(data["dislikeCount"]),
                    distanceMeters: distance,
                    coinReward: max(0, coinReward),
                    isUrgent: data["isUrgent"] as? Bool ?? false,
                    firstPhotoURL: firstPhotoURL,
                    userReaction: announcementUserReactionMap[doc.documentID],
                    rewardClaimed: announcementRewardClaimedMap[doc.documentID] ?? false
                )
            }

            nearbyAnnouncements = mappedAnnouncements
                .filter { $0.distanceMeters <= visibleRange }
                .sorted { $0.distanceMeters < $1.distanceMeters }
                .prefix(6)
                .map { $0 }

            if contentMode == .posts {
                titleText = "Nearby Posts"
                statusText = "Posts: \(nearbyPosts.count) • Announcements: \(nearbyAnnouncements.count)"
                if let nearest = nearbyPosts.first {
                    let caption = nearest.message.trimmingCharacters(in: .whitespacesAndNewlines)
                    let preview = caption.isEmpty ? "Untitled post" : String(caption.prefix(36))
                    rewardInfoText = "Nearest: \(preview)"
                    distanceText = String(format: "Distance: %.1f m", nearest.distanceMeters)
                } else if let nearestAnnouncement = nearbyAnnouncements.first {
                    rewardInfoText = "Nearest announcement: \(String(nearestAnnouncement.title.prefix(32)))"
                    distanceText = String(format: "Distance: %.1f m", nearestAnnouncement.distanceMeters)
                } else {
                    rewardInfoText = "Nearest: none"
                    distanceText = nil
                }
            }
        } catch {
            // Keep AR usable even if post fetch fails.
            nearbyPosts = []
            nearbyAnnouncements = []
            if contentMode == .posts {
                titleText = "Nearby Posts"
                statusText = "Posts in range: 0"
                rewardInfoText = "Nearest: none"
                distanceText = nil
            }
        }
    }

    private func loadARAdminConfiguration(forceRefresh: Bool = false) async -> ARAdminConfiguration {
        if !forceRefresh,
           let lastFetch = lastARAdminConfigFetch,
           Date().timeIntervalSince(lastFetch) < 300 {
            return arAdminConfigCache
        }

        do {
            let snapshot = try await db.collection("admin_configuration").document("default").getDocument()
            let data = snapshot.data() ?? [:]
            let visibleRange = max(1, doubleValue(data["postVisibleRange"], default: ARAdminConfiguration.default.postVisibleRangeMeters))
            let visibilityHours = max(1, intValue(data["postVisibilityDuration"], default: ARAdminConfiguration.default.postVisibilityDurationHours))
            arAdminConfigCache = ARAdminConfiguration(
                postVisibleRangeMeters: visibleRange,
                postVisibilityDurationHours: visibilityHours
            )
            lastARAdminConfigFetch = Date()
            return arAdminConfigCache
        } catch {
            arAdminConfigCache = .default
            lastARAdminConfigFetch = nil
            return arAdminConfigCache
        }
    }

    private func cachedStorageDownloadURL(for path: String) -> URL? {
        if let cached = photoURLCache[path] {
            return cached
        }
        guard let resolved = try? storageDownloadURL(for: path) else {
            return nil
        }
        photoURLCache[path] = resolved
        return resolved
    }

    private func parsePostDate(_ data: [String: Any]) -> Date? {
        if let timestamp = data["date"] as? Timestamp {
            return timestamp.dateValue()
        }
        if let timestamp = data["createdAt"] as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = data["date"] as? Date {
            return date
        }
        if let date = data["createdAt"] as? Date {
            return date
        }
        return nil
    }

    private func loadModelEntity(from assetPath: String) async throws -> ModelEntity {
        let downloadURL = try storageDownloadURL(for: assetPath)

        let (data, response) = try await URLSession.shared.data(from: downloadURL)
        guard let http = response as? HTTPURLResponse else {
            throw ARCameraError.invalidStorageResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let serverBody = String(data: data, encoding: .utf8)
            throw ARCameraError.assetDownloadFailed(statusCode: http.statusCode, body: serverBody)
        }
        guard !data.isEmpty else {
            throw ARCameraError.emptyAssetData
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("usdz")

        try data.write(to: tempURL, options: .atomic)
        return try await loadModelAsync(from: tempURL)
    }

    private func loadModelAsync(from fileURL: URL) async throws -> ModelEntity {
        return try await ModelEntity(contentsOf: fileURL)
    }

    private func storageDownloadURL(for assetPath: String) throws -> URL {
        guard let app = FirebaseApp.app(), let bucket = app.options.storageBucket else {
            throw ARCameraError.missingStorageBucket
        }

        // Firebase Storage REST endpoint expects object names URL-encoded (including '/').
        let safeObjectNameCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let escapedPath = assetPath.addingPercentEncoding(withAllowedCharacters: safeObjectNameCharacters) else {
            throw ARCameraError.invalidAssetPath
        }
        let urlString = "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media"

        guard let url = URL(string: urlString) else {
            throw ARCameraError.invalidAssetPath
        }

        return url
    }

    private func fetchUserCaptureProgress() async throws -> [String: ARCaptureProgress] {
        guard let uid = auth.currentUser?.uid else { return [:] }
        let snapshot = try await db.collection("users").document(uid).getDocument()
        let map = snapshot.data()?["arCaptureProgress"] as? [String: [String: Any]] ?? [:]

        var output: [String: ARCaptureProgress] = [:]
        for (spawnID, raw) in map {
            let count = intValue(raw["count"])
            let last = parseFirestoreDate(raw["lastCapturedAt"])
            output[spawnID] = ARCaptureProgress(count: count, lastCapturedAt: last)
        }
        return output
    }

    private func eligibility(for spawn: ARSpawn, now: Date) -> ARCatchEligibility {
        let progress = captureProgress(for: spawn)
        if progress.count >= spawn.catchableTime {
            return .limitReached(limit: spawn.catchableTime)
        }
        if progress.count > 0, let last = progress.lastCapturedAt,
           let next = Calendar.current.date(byAdding: .day, value: spawn.respawnDays, to: last),
           now < next {
            return .cooldown(availableAt: next)
        }
        return .available
    }

    private func captureProgress(for spawn: ARSpawn) -> ARCaptureProgress {
        if let exact = userCaptureProgress[spawn.id] {
            return exact
        }
        if let legacyKey = spawn.legacyProgressKey,
           let legacy = userCaptureProgress[legacyKey] {
            return legacy
        }
        return ARCaptureProgress(count: 0, lastCapturedAt: nil)
    }

    private func persistCapture(for spawn: ARSpawn) async throws -> (newCount: Int, newBalance: Double) {
        guard let uid = auth.currentUser?.uid else {
            throw ARCameraError.notSignedIn
        }

        let userRef = db.collection("users").document(uid)
        let now = Date()
        let result: Any?
        do {
            result = try await db.runTransaction { [self] transaction, errorPointer in
                let userSnapshot: DocumentSnapshot
                do {
                    userSnapshot = try transaction.getDocument(userRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                let userData = userSnapshot.data() ?? [:]
                var coinBalance = doubleValue(userData["coinBalance"])
                var score = intValue(userData["score"])

                var progressMap = userData["arCaptureProgress"] as? [String: [String: Any]] ?? [:]
                let progressRaw = progressMap[spawn.id] ?? {
                    if let legacyKey = spawn.legacyProgressKey {
                        return progressMap[legacyKey] ?? [:]
                    }
                    return [:]
                }()
                let previousCount = intValue(progressRaw["count"])
                let lastCapturedAt = parseFirestoreDate(progressRaw["lastCapturedAt"])

                if previousCount >= spawn.catchableTime {
                    errorPointer?.pointee = NSError(
                        domain: "ARCapture",
                        code: 1001,
                        userInfo: ["limit": spawn.catchableTime]
                    )
                    return nil
                }

                if previousCount > 0,
                   let lastCapturedAt,
                   let nextCatchAt = Calendar.current.date(byAdding: .day, value: spawn.respawnDays, to: lastCapturedAt),
                   now < nextCatchAt {
                    errorPointer?.pointee = NSError(
                        domain: "ARCapture",
                        code: 1002,
                        userInfo: ["availableAt": Timestamp(date: nextCatchAt)]
                    )
                    return nil
                }

                let newCount = previousCount + 1
                progressMap[spawn.id] = [
                    "count": newCount,
                    "lastCapturedAt": Timestamp(date: now)
                ]
                if let legacyKey = spawn.legacyProgressKey {
                    progressMap.removeValue(forKey: legacyKey)
                }

                coinBalance += spawn.coinValue
                score += spawn.pointValue

                var capturedCharacters = userData["arCapturedCharacters"] as? [[String: Any]] ?? []
                let nextCatchAt = newCount < spawn.catchableTime
                    ? Calendar.current.date(byAdding: .day, value: spawn.respawnDays, to: now)
                    : nil

                var record: [String: Any] = [
                    "spawnId": spawn.id,
                    "sourceSpawnId": spawn.sourceSpawnID,
                    "title": spawn.title,
                    "assetPath": spawn.assetPath,
                    "coinValue": spawn.coinValue,
                    "pointValue": spawn.pointValue,
                    "catchCount": newCount,
                    "catchableTime": spawn.catchableTime,
                    "lastCapturedAt": Timestamp(date: now)
                ]
                if let preview = spawn.preview {
                    record["preview"] = preview
                }
                if let rarity = spawn.rarity, !rarity.isEmpty {
                    record["rarity"] = rarity
                }
                if let description = spawn.descriptionText, !description.isEmpty {
                    record["description"] = description
                }
                if let locationName = spawn.locationName {
                    record["locationName"] = locationName
                }
                record["latitude"] = spawn.lat
                record["longitude"] = spawn.lon
                if let nextCatchAt {
                    record["nextCatchAt"] = Timestamp(date: nextCatchAt)
                }

                if let idx = capturedCharacters.firstIndex(where: { ($0["spawnId"] as? String) == spawn.id }) {
                    capturedCharacters[idx] = record
                } else {
                    capturedCharacters.append(record)
                }

                transaction.setData([
                    "coinBalance": coinBalance,
                    "score": score,
                    "arCaptureProgress": progressMap,
                    "arCapturedCharacters": capturedCharacters,
                    "updatedAt": Timestamp(date: now)
                ], forDocument: userRef, merge: true)

                return ["newCount": Double(newCount), "newBalance": coinBalance]
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == "ARCapture" {
                if nsError.code == 1001 {
                    let limit = nsError.userInfo["limit"] as? Int ?? spawn.catchableTime
                    throw ARCameraError.captureLimitReached(limit: limit)
                }
                if nsError.code == 1002 {
                    if let timestamp = nsError.userInfo["availableAt"] as? Timestamp {
                        throw ARCameraError.captureCooldown(availableAt: timestamp.dateValue())
                    }
                    throw ARCameraError.captureCooldown(
                        availableAt: Calendar.current.date(byAdding: .day, value: spawn.respawnDays, to: now) ?? now
                    )
                }
            }
            throw error
        }

        guard let payload = result as? [String: Double],
              let newCountDouble = payload["newCount"],
              let newBalance = payload["newBalance"] else {
            throw ARCameraError.captureFailed
        }
        return (Int(newCountDouble), newBalance)
    }

    private func intValue(_ value: Any?, default defaultValue: Int = 0) -> Int {
        if let intValue = value as? Int { return intValue }
        if let number = value as? NSNumber { return number.intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String, let parsed = Double(stringValue) { return Int(parsed) }
        return defaultValue
    }

    private func doubleValue(_ value: Any?, default defaultValue: Double = 0) -> Double {
        if let doubleValue = value as? Double { return doubleValue }
        if let number = value as? NSNumber { return number.doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let stringValue = value as? String { return Double(stringValue) ?? defaultValue }
        return defaultValue
    }

    private func storageMediaURL(from rawValue: String?) -> URL? {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("https://") || value.hasPrefix("http://") {
            return URL(string: value)
        }

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        if value.hasPrefix("gs://"), let gsURL = URL(string: value), let bucket = gsURL.host {
            var objectPath = gsURL.path
            while objectPath.hasPrefix("/") { objectPath.removeFirst() }
            guard let escapedPath = objectPath.addingPercentEncoding(withAllowedCharacters: allowed) else {
                return nil
            }
            return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
        }

        guard let bucket = FirebaseApp.app()?.options.storageBucket else { return nil }
        var objectPath = value
        while objectPath.hasPrefix("/") { objectPath.removeFirst() }
        guard let escapedPath = objectPath.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(escapedPath)?alt=media")
    }

    private func formatCoins(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func toDouble(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let number = value as? NSNumber { return number.doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        return nil
    }

    private func proximityScale(for distance: Double) -> CGFloat {
        // Restore stronger floating feel while keeping overlap manageable.
        let clampedDistance = max(0, min(distance, 30))
        let normalized = 1.0 - (clampedDistance / 30.0)
        return CGFloat(0.88 + (0.24 * normalized))
    }

    private func postCategory(from raw: Any?) -> Post.PostCategory {
        guard let raw else { return .casual }
        let text = String(describing: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .casual }
        let normalizedKey = text
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        switch normalizedKey {
        case "casual":
            return .casual
        case "lost & found", "lost and found", "lostfound":
            return .lostFound
        case "complaint", "complaints":
            return .complaint
        case "event":
            return .event
        case "question":
            return .question
        case "announcement":
            return .casual
        case "ar challenge", "archallenge":
            return .arChallenge
        default:
            return .casual
        }
    }

    private func characterScale(for distance: Double, spawn: ARSpawn) -> CGFloat {
        guard spawn.revealRadius > 0 else { return 1.0 }
        let clamped = max(0, min(distance, spawn.revealRadius))
        let normalized = 1.0 - (clamped / spawn.revealRadius)
        // Far: 0.85x, Near: 1.55x
        return CGFloat(0.85 + (0.70 * normalized))
    }

    private func parseFirestoreDate(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = value as? Date {
            return date
        }
        if let seconds = value as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }
        if let seconds = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(seconds))
        }
        return nil
    }
}

private struct ARCaptureProgress {
    let count: Int
    let lastCapturedAt: Date?
}

private struct ARCaptureCelebration: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let descriptionText: String?
    let rarity: String?
    let imageURL: URL?
    let coinText: String
    let pointsText: String
}

private enum ARCatchEligibility {
    case available
    case cooldown(availableAt: Date)
    case limitReached(limit: Int)
}

private struct ARSpawn {
    let id: String
    let sourceSpawnID: String
    let title: String
    let assetPath: String
    let lat: Double
    let lon: Double
    let alt: Double
    let revealRadius: Double
    let catchRadius: Double
    let coinValue: Double
    let pointValue: Int
    let catchableTime: Int
    let respawnDays: Int
    let preview: String?
    let descriptionText: String?
    let rarity: String?
    let locationName: String?
    let legacyProgressKey: String?

    var location: CLLocation {
        CLLocation(latitude: lat, longitude: lon)
    }

    static func fromDocument(documentID: String, data: [String: Any]) -> [ARSpawn] {
        guard
            let title = (data["title"] as? String) ?? (data["name"] as? String),
            let assetPath = (data["assetPath"] as? String) ?? (data["modelPath"] as? String),
            let revealRadius = ARSpawn.toDouble(data["revealRadius"]),
            let catchRadius = ARSpawn.toDouble(data["catchRadius"])
        else {
            return []
        }

        let alt = ARSpawn.toDouble(data["alt"]) ?? 0
        let coinValue = ARSpawn.toDouble(data["coin_value"]) ?? 0
        let pointValue = ARSpawn.toInt(data["point"]) ?? 0
        let catchableTime = max(1, ARSpawn.toInt(data["catchable_time"]) ?? 1)
        let respawnDays = max(1, ARSpawn.toInt(data["respawn_days"]) ?? 1)
        let preview = (data["preview"] as? String) ?? (data["previewPath"] as? String)
        let descriptionText = data["description"] as? String
        let rarity = data["rarity"] as? String
        let fixedLocations = data["fixedLocations"] as? [[String: Any]] ?? []

        var locations: [(lat: Double, lon: Double, name: String?, isPrimary: Bool)] = []
        for entry in fixedLocations {
            guard
                let lat = ARSpawn.toDouble(entry["latitude"]),
                let lon = ARSpawn.toDouble(entry["longitude"])
            else { continue }
            locations.append((lat, lon, entry["name"] as? String, false))
        }

        if locations.isEmpty,
           let lat = ARSpawn.toDouble(data["latitude"]),
           let lon = ARSpawn.toDouble(data["longitude"]) {
            locations.append((lat, lon, data["name"] as? String, true))
        }

        return locations.map { location in
            ARSpawn(
                id: ARSpawn.locationScopedID(documentID: documentID, lat: location.lat, lon: location.lon),
                sourceSpawnID: documentID,
                title: title,
                assetPath: assetPath,
                lat: location.lat,
                lon: location.lon,
                alt: alt,
                revealRadius: revealRadius,
                catchRadius: catchRadius,
                coinValue: coinValue,
                pointValue: pointValue,
                catchableTime: catchableTime,
                respawnDays: respawnDays,
                preview: preview,
                descriptionText: descriptionText,
                rarity: rarity,
                locationName: location.name,
                legacyProgressKey: location.isPrimary ? documentID : nil
            )
        }
    }

    private init(
        id: String,
        sourceSpawnID: String,
        title: String,
        assetPath: String,
        lat: Double,
        lon: Double,
        alt: Double,
        revealRadius: Double,
        catchRadius: Double,
        coinValue: Double,
        pointValue: Int,
        catchableTime: Int,
        respawnDays: Int,
        preview: String?,
        descriptionText: String?,
        rarity: String?,
        locationName: String?,
        legacyProgressKey: String?
    ) {
        self.id = id
        self.sourceSpawnID = sourceSpawnID
        self.title = title
        self.assetPath = assetPath
        self.lat = lat
        self.lon = lon
        self.alt = alt
        self.revealRadius = revealRadius
        self.catchRadius = catchRadius
        self.coinValue = coinValue
        self.pointValue = pointValue
        self.catchableTime = catchableTime
        self.respawnDays = respawnDays
        self.preview = preview
        self.descriptionText = descriptionText
        self.rarity = rarity
        self.locationName = locationName
        self.legacyProgressKey = legacyProgressKey
    }

    private static func locationScopedID(documentID: String, lat: Double, lon: Double) -> String {
        let latString = String(format: "%.6f", lat)
        let lonString = String(format: "%.6f", lon)
        return "\(documentID)@\(latString),\(lonString)"
    }

    private static func toDouble(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let intValue = value as? Int {
            return Double(intValue)
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return nil
    }

    private static func toInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        return nil
    }
}

private struct ARNearbyPost: Identifiable {
    let id: String
    let message: String
    let category: Post.PostCategory
    let likeCount: Int
    let dislikeCount: Int
    let distanceMeters: Double
    let firstPhotoURL: URL?
    let emojiPin: String?
    let proximityScale: CGFloat
}

private struct ARNearbyAnnouncement: Identifiable {
    let id: String
    let title: String
    let body: String
    var likeCount: Int
    var dislikeCount: Int
    let distanceMeters: Double
    let coinReward: Double
    let isUrgent: Bool
    let firstPhotoURL: URL?
    var userReaction: String?
    var rewardClaimed: Bool
}

private struct ARNearbyPostCard: View {
    let post: ARNearbyPost

    private var visual: ContentSymbolKit.PostVisual {
        ContentSymbolKit.postVisual(for: post.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(post.category.rawValue, systemImage: visual.symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(visual.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(visual.color.opacity(0.18))
                    .clipShape(Capsule())
                if let emoji = post.emojiPin {
                    HStack(spacing: 4) {
                        Text(emoji)
                        Text("Special")
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.pink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.16))
                    .clipShape(Capsule())
                }
                Spacer()
            }

            if let url = post.firstPhotoURL {
                CachedRemoteImage(url: url, cacheKey: url.absoluteString) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: 190, height: 98)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Label {
                Text(post.message)
                    .lineLimit(2)
            } icon: {
                Image(systemName: "text.bubble.fill")
            }
            .font(.footnote)
            .foregroundColor(.white)

            HStack(spacing: 12) {
                Label("\(post.likeCount)", systemImage: "hand.thumbsup.fill")
                    .font(.caption)
                    .foregroundColor(.green.opacity(0.9))
                Label("\(post.dislikeCount)", systemImage: "hand.thumbsdown.fill")
                    .font(.caption)
                    .foregroundColor(.orange.opacity(0.9))
                Spacer()
                Text(String(format: "%.0fm", post.distanceMeters))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(10)
        .frame(width: 200, alignment: .leading)
        .background(visual.color.opacity(0.28))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(visual.color.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(post.proximityScale)
        .animation(.easeOut(duration: 0.18), value: post.proximityScale)
    }
}

private struct ARNearbyAnnouncementCard: View {
    let announcement: ARNearbyAnnouncement
    let onLike: () -> Void
    let onDislike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(announcement.isUrgent ? "Urgent" : "Announcement", systemImage: "megaphone.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(announcement.isUrgent ? .red : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((announcement.isUrgent ? Color.red : Color.blue).opacity(0.16))
                    .clipShape(Capsule())
                Spacer()
                Label(String(format: "+%.1f", announcement.coinReward), systemImage: "bitcoinsign.circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Color.Brand.coin)
            }

            Text(announcement.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            if let url = announcement.firstPhotoURL {
                CachedRemoteImage(url: url, cacheKey: url.absoluteString) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: 224, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text(announcement.body)
                .font(.footnote)
                .foregroundColor(.white)
                .lineLimit(2)

            HStack(spacing: 6) {
                if let userReaction = announcement.userReaction {
                    Label(
                        userReaction == "like" ? "You liked" : "You disliked",
                        systemImage: userReaction == "like" ? "hand.thumbsup.fill" : "hand.thumbsdown.fill"
                    )
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                }
                Label(
                    announcement.rewardClaimed ? "Reward claimed" : String(format: "Earn +%.1f", announcement.coinReward),
                    systemImage: announcement.rewardClaimed ? "checkmark.seal.fill" : "bitcoinsign.circle.fill"
                )
                .font(.caption2.weight(.bold))
                .foregroundColor(announcement.rewardClaimed ? Color.Brand.coin : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(announcement.rewardClaimed ? Color.Brand.coin.opacity(0.2) : Color.white.opacity(0.18))
                .clipShape(Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                Spacer()
            }

            HStack(spacing: 8) {
                Button(action: onLike) {
                    Label("\(announcement.likeCount)", systemImage: "hand.thumbsup.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onDislike) {
                    Label("\(announcement.dislikeCount)", systemImage: "hand.thumbsdown.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Spacer()
                Text(String(format: "%.0fm", announcement.distanceMeters))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(10)
        .frame(width: 232, alignment: .leading)
        .background(Color.blue.opacity(0.24))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum ARCameraError: LocalizedError {
    case noActiveSpawns
    case noCatchableSpawns
    case missingStorageBucket
    case invalidAssetPath
    case invalidStorageResponse
    case emptyAssetData
    case assetDownloadFailed(statusCode: Int, body: String?)
    case notSignedIn
    case captureLimitReached(limit: Int)
    case captureCooldown(availableAt: Date)
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .noActiveSpawns:
            return "No active spawns found in Firestore."
        case .noCatchableSpawns:
            return "No catchable spawns right now."
        case .missingStorageBucket:
            return "Firebase storage bucket is not configured."
        case .invalidAssetPath:
            return "Invalid asset path."
        case .invalidStorageResponse:
            return "Invalid response while downloading AR asset."
        case .emptyAssetData:
            return "Downloaded AR asset is empty."
        case .assetDownloadFailed(let statusCode, let body):
            if let body, !body.isEmpty {
                return "Storage download failed (\(statusCode)): \(body)"
            }
            return "Storage download failed with status \(statusCode)."
        case .notSignedIn:
            return "You need to sign in first."
        case .captureLimitReached(let limit):
            return "Capture limit reached (\(limit))."
        case .captureCooldown(let availableAt):
            let formatter = RelativeDateTimeFormatter()
            return "Available \(formatter.localizedString(for: availableAt, relativeTo: Date()))."
        case .captureFailed:
            return "Failed to persist capture."
        }
    }
}
