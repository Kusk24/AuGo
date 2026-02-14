import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Combine
import UIKit
import FirebaseCore
import FirebaseFirestore

struct ARCameraView: View {
    @StateObject private var viewModel = ARCameraViewModel()

    var body: some View {
        ZStack {
            ARRealityContainerView(
                modelEntity: viewModel.modelEntity,
                shouldRenderModel: viewModel.canRenderModel,
                renderSpawnID: viewModel.renderSpawnID,
                onCapture: {
                    viewModel.captureCurrentSpawn()
                }
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
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

                if let coinValueText = viewModel.coinValueText {
                    Text(coinValueText)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Color.Brand.coin)
                }

                if viewModel.canRenderModel {
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
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

private struct ARRealityContainerView: UIViewRepresentable {
    let modelEntity: ModelEntity?
    let shouldRenderModel: Bool
    let renderSpawnID: String?
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
        var onCapture: () -> Void

        init(onCapture: @escaping () -> Void) {
            self.onCapture = onCapture
        }

        func attach(to arView: ARView) {
            self.arView = arView
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tap)
        }

        func clearModelIfNeeded() {
            currentModelEntity = nil
            currentSpawnID = nil
            anchorEntity?.removeFromParent()
            anchorEntity = nil
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
    }
}

private final class ARCameraViewModel: ObservableObject {
    @Published var titleText = "AR Hunt"
    @Published var statusText = "Loading nearby AR spawn..."
    @Published var distanceText: String?
    @Published var errorText: String?
    @Published var canRenderModel = false
    @Published var modelEntity: ModelEntity?
    @Published var renderSpawnID: String?
    @Published var coinValueText: String?
    @Published var catchInstructionText = "Get inside catch radius to start combo"

    private let locationManager = LocationManager()
    private let db = Firestore.firestore()

    private var activeSpawn: ARSpawn?
    private var didStart = false
    private var distanceMonitorTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var comboHits = 0
    private var lastHitAt: Date?
    private let comboRequiredHits = 3
    private let comboWindowSeconds: TimeInterval = 2.0

    func onAppear() {
        guard !didStart else { return }
        didStart = true

        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        Task {
            await loadNearestSpawnAndAssetIfNeeded()
        }
    }

    func onDisappear() {
        locationManager.stopUpdatingLocation()
        distanceMonitorTask?.cancel()
        didStart = false
    }

    func captureCurrentSpawn() {
        guard let spawn = activeSpawn else { return }
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
        renderSpawnID = nil
        canRenderModel = false
        statusText = "Captured \(spawn.title)! +\(spawn.coinValue) coins"
        distanceText = nil
        catchInstructionText = "Captured"
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor
    private func loadNearestSpawnAndAssetIfNeeded() async {
        do {
            let spawn = try await fetchNearestActiveSpawn()
            activeSpawn = spawn
            titleText = spawn.title
            coinValueText = "+\(spawn.coinValue) coins"

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

        guard let userLocation = locationManager.lastLocation else {
            return spawns[0]
        }

        let nearest = spawns.min { lhs, rhs in
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
        return spawn.location.distance(from: userLocation)
    }

    private func updateRenderEligibility() {
        guard let spawn = activeSpawn else {
            canRenderModel = false
            renderSpawnID = nil
            return
        }

        guard let distance = distanceToSpawn(spawn) else {
            canRenderModel = false
            renderSpawnID = nil
            statusText = "Waiting for accurate location..."
            distanceText = "Waiting for GPS signal..."
            return
        }

        distanceText = String(format: "Distance: %.1f m", distance)

        if distance <= spawn.revealRadius {
            canRenderModel = true
            renderSpawnID = spawn.id
            statusText = "Spawn unlocked"
            if distance <= spawn.catchRadius {
                catchInstructionText = "Tap 3x quickly to catch (+\(spawn.coinValue) coins)"
            } else {
                let need = max(distance - spawn.catchRadius, 0)
                catchInstructionText = String(format: "Move %.1f m closer to start 3-hit combo", need)
            }
        } else {
            canRenderModel = false
            renderSpawnID = nil
            comboHits = 0
            lastHitAt = nil
            let remaining = max(distance - spawn.revealRadius, 0)
            statusText = String(format: "Move %.1f m closer to reveal", remaining)
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
    let coinValue: Int

    var location: CLLocation {
        CLLocation(latitude: lat, longitude: lon)
    }

    init?(documentID: String, data: [String: Any]) {
        guard
            let title = data["title"] as? String,
            let assetPath = data["assetPath"] as? String,
            let lat = ARSpawn.toDouble(data["lat"]),
            let lon = ARSpawn.toDouble(data["lon"]),
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
        self.coinValue = ARSpawn.toInt(data["coin_value"]) ?? ARSpawn.toInt(data["coinValue"]) ?? 0
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

private enum ARCameraError: LocalizedError {
    case noActiveSpawns
    case missingStorageBucket
    case invalidAssetPath
    case invalidStorageResponse
    case emptyAssetData
    case assetDownloadFailed(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .noActiveSpawns:
            return "No active spawns found in Firestore."
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
        }
    }
}
