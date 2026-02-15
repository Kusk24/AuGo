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
                        Text(viewModel.showPostsInCharacter ? "Hide Posts Overlay" : "Show Posts Overlay")
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
        }
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

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.onCapture = onCapture
        context.coordinator.updateFloatingPosts(nearbyPosts)
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
        private var currentSpawnID: String?
        private var baseCharacterScale: SIMD3<Float>?
        private var postAnchors: [String: AnchorEntity] = [:]
        private var postCards: [String: UIHostingController<ARNearbyPostCard>] = [:]
        private var displayLink: CADisplayLink?
        private let floatingStartTime = CACurrentMediaTime()
        var onCapture: () -> Void

        init(onCapture: @escaping () -> Void) {
            self.onCapture = onCapture
        }

        func attach(to arView: ARView) {
            self.arView = arView
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tap)
            startDisplayLink()
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

            let activeIDs = Set(posts.map(\.id))
            for existingID in postAnchors.keys where !activeIDs.contains(existingID) {
                postAnchors[existingID]?.removeFromParent()
                postAnchors.removeValue(forKey: existingID)

                postCards[existingID]?.view.removeFromSuperview()
                postCards.removeValue(forKey: existingID)
            }

            for (index, post) in posts.enumerated() {
                if let host = postCards[post.id] {
                    host.rootView = ARNearbyPostCard(post: post)
                    continue
                }

                let anchor = AnchorEntity(world: floatingPostPosition(index: index, arView: arView))
                arView.scene.addAnchor(anchor)
                postAnchors[post.id] = anchor

                let host = UIHostingController(rootView: ARNearbyPostCard(post: post))
                host.view.backgroundColor = .clear
                host.view.frame = CGRect(x: 0, y: 0, width: 280, height: 230)
                arView.addSubview(host.view)
                postCards[post.id] = host
            }

            updateFloatingPostScreenPositions()
        }

        private func floatingPostPosition(index: Int, arView: ARView) -> SIMD3<Float> {
            let cameraTransform = arView.cameraTransform.matrix
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            let forward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
            let right = SIMD3<Float>(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z)
            let up = SIMD3<Float>(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z)

            let normalizedForward = simd_normalize(forward)
            let normalizedRight = simd_normalize(right)
            let normalizedUp = simd_normalize(up)

            let horizontalOffset = Float(index % 2 == 0 ? -1 : 1) * (0.35 + Float(index) * 0.12)
            let depth = 1.7 + Float(index) * 0.35
            let height = 0.2 + Float(index % 3) * 0.08

            return cameraPosition
                + normalizedForward * depth
                + normalizedRight * horizontalOffset
                + normalizedUp * height
        }

        private func startDisplayLink() {
            displayLink?.invalidate()
            let link = CADisplayLink(target: self, selector: #selector(onDisplayTick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc
        private func onDisplayTick() {
            updateFloatingPostScreenPositions()
        }

        private func updateFloatingPostScreenPositions() {
            guard let arView else { return }

            let t = CACurrentMediaTime() - floatingStartTime
            for (id, anchor) in postAnchors {
                guard let host = postCards[id] else { continue }
                let worldPosition = anchor.position(relativeTo: nil)
                guard let projected = arView.project(worldPosition) else {
                    host.view.isHidden = true
                    continue
                }

                let bob = CGFloat(sin(t * 1.7 + Double(abs(id.hashValue % 7))) * 8.0)
                host.view.isHidden = false
                host.view.center = CGPoint(x: projected.x, y: projected.y + bob)
            }
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
            displayLink?.invalidate()
            postCards.values.forEach { $0.view.removeFromSuperview() }
            postCards.removeAll()
            postAnchors.values.forEach { $0.removeFromParent() }
            postAnchors.removeAll()
        }
    }
}

private final class ARCameraViewModel: ObservableObject {
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
    @Published var nearbyPosts: [ARNearbyPost] = []
    @Published var showPostsInCharacter = false

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
            if showPostsInCharacter {
                startNearbyPostsMonitoring()
            } else {
                nearbyPostsMonitorTask?.cancel()
                nearbyPosts = []
            }
            smoothedDistanceMeters = nil
            loadSpawnTask?.cancel()
            loadSpawnTask = Task { @MainActor in
                await loadNearestSpawnAndAssetIfNeeded()
            }
        case .posts:
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

    @MainActor
    private func loadNearestSpawnAndAssetIfNeeded() async {
        errorText = nil
        do {
            let spawn = try await fetchNearestActiveSpawn()
            activeSpawn = spawn
            titleText = spawn.title
            rewardInfoText = "Nearest: \(spawn.title) • +\(formatCoins(spawn.coinValue)) coins • +\(spawn.pointValue) points"

            let currentDistance = distanceToSpawn(spawn)
            if let currentDistance {
                distanceText = String(format: "Distance: %.1f m", currentDistance)
            } else {
                distanceText = "Waiting for GPS signal..."
            }

            modelEntity = try await loadModelEntity(from: spawn.assetPath)
            statusText = "Move closer to reveal AR object"

            startDistanceMonitoring()
            updateRenderEligibility()
        } catch let arError as ARCameraError {
            switch arError {
            case .noCatchableSpawns:
                titleText = "AR Hunt"
                statusText = "No catchable AR characters right now"
                catchInstructionText = "Try again later"
                rewardInfoText = nil
                distanceText = nil
                canRenderModel = false
                renderSpawnID = nil
            case .noActiveSpawns:
                titleText = "AR Hunt"
                statusText = "No active AR spawns"
                rewardInfoText = nil
                distanceText = nil
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

        let spawns: [ARSpawn] = snapshot.documents.compactMap { doc in
            ARSpawn(documentID: doc.documentID, data: doc.data())
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
        guard let userLocation = locationManager.lastLocation else {
            nearbyPosts = []
            return
        }

        do {
            let snapshot = try await db.collection("posts")
                .whereField("status", isEqualTo: "active")
                .limit(to: 60)
                .getDocuments()

            let mapped = snapshot.documents.compactMap { doc -> ARNearbyPost? in
                let data = doc.data()
                guard
                    let content = data["content"] as? String,
                    let lat = toDouble(data["latitude"]),
                    let lon = toDouble(data["longitude"])
                else { return nil }

                let likeCount = intValue(data["likeCount"])
                let dislikeCount = intValue(data["dislikeCount"])
                let category = postCategory(from: data["category"])
                let postLocation = CLLocation(latitude: lat, longitude: lon)
                let distance = postLocation.distance(from: userLocation)

                let photoPaths = data["photoPaths"] as? [String] ?? []
                let firstPath = photoPaths.first
                    ?? (data["photoPath"] as? String)
                    ?? (data["imagePath"] as? String)
                let firstPhotoURL = firstPath.flatMap { path in
                    try? storageDownloadURL(for: path)
                }

                return ARNearbyPost(
                    id: doc.documentID,
                    message: content,
                    category: category,
                    likeCount: likeCount,
                    dislikeCount: dislikeCount,
                    distanceMeters: distance,
                    firstPhotoURL: firstPhotoURL,
                    proximityScale: proximityScale(for: distance)
                )
            }

            nearbyPosts = mapped
                .filter { $0.distanceMeters <= 30 }
                .sorted { $0.distanceMeters < $1.distanceMeters }
                .prefix(8)
                .map { $0 }

            titleText = "Nearby Posts"
            statusText = "Posts in range: \(nearbyPosts.count)"
            if let nearest = nearbyPosts.first {
                let caption = nearest.message.trimmingCharacters(in: .whitespacesAndNewlines)
                let preview = caption.isEmpty ? "Untitled post" : String(caption.prefix(36))
                rewardInfoText = "Nearest: \(preview)"
                distanceText = String(format: "Distance: %.1f m", nearest.distanceMeters)
            } else {
                rewardInfoText = "Nearest: none"
                distanceText = nil
            }
        } catch {
            // Keep AR usable even if post fetch fails.
            nearbyPosts = []
            titleText = "Nearby Posts"
            statusText = "Posts in range: 0"
            rewardInfoText = "Nearest: none"
            distanceText = nil
        }
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
        let progress = userCaptureProgress[spawn.id] ?? ARCaptureProgress(count: 0, lastCapturedAt: nil)
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
                let progressRaw = progressMap[spawn.id] ?? [:]
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

                coinBalance += spawn.coinValue
                score += spawn.pointValue

                var capturedCharacters = userData["arCapturedCharacters"] as? [[String: Any]] ?? []
                let nextCatchAt = newCount < spawn.catchableTime
                    ? Calendar.current.date(byAdding: .day, value: spawn.respawnDays, to: now)
                    : nil

                var record: [String: Any] = [
                    "spawnId": spawn.id,
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

    private func intValue(_ value: Any?) -> Int {
        if let intValue = value as? Int { return intValue }
        if let number = value as? NSNumber { return number.intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        return 0
    }

    private func doubleValue(_ value: Any?) -> Double {
        if let doubleValue = value as? Double { return doubleValue }
        if let number = value as? NSNumber { return number.doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let stringValue = value as? String { return Double(stringValue) ?? 0 }
        return 0
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
        // 30m -> 0.72x, 0m -> 1.20x
        let clampedDistance = max(0, min(distance, 30))
        let normalized = 1.0 - (clampedDistance / 30.0)
        return CGFloat(0.72 + (0.48 * normalized))
    }

    private func postCategory(from raw: Any?) -> Post.PostCategory {
        guard let raw else { return .casual }
        let text = String(describing: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .casual }
        let normalized = text.prefix(1).uppercased() + text.dropFirst().lowercased()
        return Post.PostCategory(rawValue: normalized) ?? .casual
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

private enum ARCatchEligibility {
    case available
    case cooldown(availableAt: Date)
    case limitReached(limit: Int)
}

private struct ARSpawn {
    let id: String
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

    var location: CLLocation {
        CLLocation(latitude: lat, longitude: lon)
    }

    init?(documentID: String, data: [String: Any]) {
        guard
            let title = data["title"] as? String,
            let assetPath = data["assetPath"] as? String,
            let lat = ARSpawn.toDouble(data["latitude"]),
            let lon = ARSpawn.toDouble(data["longitude"]),
            let revealRadius = ARSpawn.toDouble(data["revealRadius"]),
            let catchRadius = ARSpawn.toDouble(data["catchRadius"])
        else {
            return nil
        }

        self.id = documentID
        self.title = title
        self.assetPath = assetPath
        self.lat = lat
        self.lon = lon
        self.alt = ARSpawn.toDouble(data["alt"]) ?? 0
        self.revealRadius = revealRadius
        self.catchRadius = catchRadius
        self.coinValue = ARSpawn.toDouble(data["coin_value"]) ?? 0
        self.pointValue = ARSpawn.toInt(data["point"]) ?? 0
        self.catchableTime = max(1, ARSpawn.toInt(data["catchable_time"]) ?? 1)
        self.respawnDays = max(1, ARSpawn.toInt(data["respawn_days"]) ?? 1)
        self.preview = data["preview"] as? String
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
    let proximityScale: CGFloat
}

private struct ARNearbyPostCard: View {
    let post: ARNearbyPost

    private var categoryColor: Color {
        switch post.category {
        case .casual:
            return .teal
        case .event:
            return .purple
        case .question:
            return .blue
        case .announcement:
            return .orange
        case .arChallenge:
            return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(post.category.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.18))
                    .clipShape(Capsule())
                Spacer()
            }

            if let url = post.firstPhotoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.2))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.2))
                            Image(systemName: "photo")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 220, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text(post.message)
                .font(.footnote)
                .foregroundColor(.white)
                .lineLimit(3)

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
        .frame(width: 230, alignment: .leading)
        .background(categoryColor.opacity(0.28))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(categoryColor.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(post.proximityScale)
        .animation(.easeOut(duration: 0.18), value: post.proximityScale)
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
