import ARKit
import Combine
import RealityKit
import CoreMotion
import CoreHaptics
import simd

enum ScanMode {
    case waiting       // Waiting to start measurement
    case scanning      // In process of measuring a wall
    case connecting    // Ready to start a new measurement
    case completed     // Measurement complete
}

class RoomScanManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var sessionInfo = "Place your phone against one wall and tap 'Measure Wall'"
    @Published var trackingState: String = "Initializing"
    @Published var scanMode: ScanMode = .waiting
    @Published var wallCount: Int = 0
    @Published var currentWallLength: Float = 0.0
    @Published var isARSupported: Bool = true
    @Published var isMotionAvailable: Bool = true
    
    let arView = ARView(frame: .zero)
    let motionManager = CMMotionManager()
    let roomModel = RoomModel()
    
    private var cancellables = Set<AnyCancellable>()
    private var currentWallStartPosition: simd_float3?
    private var currentWallNormal: simd_float3?
    private var queue = OperationQueue()
    private var hapticEngine: CHHapticEngine?
    
    override init() {
        super.init()
        checkDeviceCapabilities()
        setupMotionManager()
        setupARSession()
        setupHaptics()
        
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
    }
    
    private func checkDeviceCapabilities() {
        isARSupported = ARWorldTrackingConfiguration.isSupported
        isMotionAvailable = motionManager.isDeviceMotionAvailable
        
        if !isARSupported {
            sessionInfo = "This device doesn't support AR"
        }
        
        if !isMotionAvailable {
            sessionInfo = "This device doesn't have required motion sensors"
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine error: \(error)")
        }
    }
    
    private func playHapticFeedback(intensity: Float = 1.0, sharpness: Float = 1.0) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                              value: intensity)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                              value: sharpness)
        
        let event = CHHapticEvent(eventType: .hapticTransient,
                                 parameters: [intensity, sharpness],
                                 relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
    
    func setupARSession() {
        guard isARSupported else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Simplified configuration for better performance
        configuration.environmentTexturing = .none
        configuration.isAutoFocusEnabled = true
        configuration.worldAlignment = .gravity
        
        arView.session.delegate = self
        arView.automaticallyConfigureSession = false
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isSessionRunning = true
        }
    }
    
    func setupMotionManager() {
        guard isMotionAvailable else { return }
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
                guard let self = self, let motion = motion, error == nil else { return }
                
                // Use motion data to get device orientation relative to gravity
                let gravity = motion.gravity
                let normal = simd_float3(Float(-gravity.x), Float(-gravity.y), Float(-gravity.z))
                
                DispatchQueue.main.async {
                    self.currentWallNormal = normal
                }
            }
        }
    }
    
    // User manually initiates measurement
    func beginWallDetection() {
        guard let cameraTransform = getCurrentCameraTransform() else {
            sessionInfo = "Cannot detect position. Try again."
            return
        }
        
        // Clear previous visualizations
        arView.scene.anchors.removeAll()
        
        // Start new measurement
        scanMode = .scanning
        currentWallStartPosition = cameraTransform.position
        
        // Provide feedback
        playHapticFeedback(intensity: 0.8, sharpness: 0.5)
        
        // Visualize start point
        addSphereAnchor(at: cameraTransform.position, color: .green)
        
        sessionInfo = "Starting point marked! Now walk to opposite wall and press 'Capture Distance'"
        currentWallLength = 0.0
    }
    
    // User manually completes measurement
    func endWallDetection() {
        guard let startPosition = currentWallStartPosition,
              let endPosition = getCurrentCameraTransform()?.position else {
            sessionInfo = "Missing position data. Try again."
            return
        }
        
        // Calculate the distance between start and end points
        let distance = simd_distance(startPosition, endPosition)
        
        if distance < 0.1 {
            // Too short - provide feedback
            sessionInfo = "Distance too short (< 10 cm). Move further away."
            playHapticFeedback(intensity: 0.3, sharpness: 0.9)
            return
        }
        
        // Valid measurement - add to room model
        let wallNormal = currentWallNormal ?? simd_float3(0, 0, 0)
        roomModel.addWall(startPoint: startPosition, endPoint: endPosition, normalVector: wallNormal)
        
        // Visualize end point and measurement
        addSphereAnchor(at: endPosition, color: .red)
        addLineAnchor(from: startPosition, to: endPosition)
        playHapticFeedback(intensity: 1.0, sharpness: 1.0)
        
        // Update UI
        wallCount += 1
        sessionInfo = "Measured: \(Int(distance * 100)) cm between walls"
        scanMode = .connecting
        
        // Reset for next measurement
        currentWallStartPosition = nil
        currentWallLength = 0.0
    }
    
    // Get camera position
    private func getCurrentCameraTransform() -> (position: simd_float3, orientation: simd_quatf)? {
        guard let frame = arView.session.currentFrame else { return nil }
        let transform = frame.camera.transform
        let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let orientation = simd_quatf(transform)
        return (position, orientation)
    }
    
    // Reset everything
    func resetScan() {
        roomModel.clear()
        wallCount = 0
        scanMode = .waiting
        sessionInfo = "Place your phone against one wall and tap 'Measure Wall'"
        
        // Clear visualizations
        arView.scene.anchors.removeAll()
        
        // Reset tracking
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .none
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Reset state
        currentWallStartPosition = nil
        currentWallLength = 0.0
        
        // Feedback
        playHapticFeedback(intensity: 0.3, sharpness: 0.3)
    }
    
    // Add a sphere to visualize points
    private func addSphereAnchor(at position: simd_float3, color: UIColor) {
        let anchor = AnchorEntity(world: position)
        
        // Create sphere to mark the point
        let mesh = MeshResource.generateSphere(radius: 0.05)
        let material = SimpleMaterial(color: color, roughness: 0.8, isMetallic: false)
        let sphere = ModelEntity(mesh: mesh, materials: [material])
        anchor.addChild(sphere)
        
        arView.scene.addAnchor(anchor)
    }
    
    // Add a line to visualize measurement
    private func addLineAnchor(from start: simd_float3, to end: simd_float3) {
        let anchor = AnchorEntity()
        let midpoint = (start + end) / 2
        anchor.position = midpoint
        
        // Calculate distance
        let distance = simd_distance(start, end)
        
        // Create cylinder for the line
        let mesh = MeshResource.generateCylinder(height: distance, radius: 0.01)
        let material = SimpleMaterial(color: .blue, roughness: 1.0, isMetallic: false)
        let cylinder = ModelEntity(mesh: mesh, materials: [material])
        
        // Orient cylinder to connect the points
        let direction = simd_normalize(end - start)
        let defaultDirection = simd_float3(0, 1, 0)
        
        let dot = simd_dot(defaultDirection, direction)
        let rotationAxis: simd_float3
        
        if abs(abs(dot) - 1) < 0.0001 {
            rotationAxis = simd_normalize(simd_float3(1, 0, 0))
        } else {
            rotationAxis = simd_normalize(simd_cross(defaultDirection, direction))
        }
        
        let rotationAngle = acos(simd_clamp(dot, -1.0, 1.0))
        cylinder.orientation = simd_quatf(angle: rotationAngle, axis: rotationAxis)
        
        anchor.addChild(cylinder)
        
        // Add distance label
        let textMesh = MeshResource.generateText(
            "\(Int(distance * 100)) cm",
            extrusionDepth: 0.001,
            font: .boldSystemFont(ofSize: 0.05)
        )
        
        let textEntity = ModelEntity(
            mesh: textMesh,
            materials: [SimpleMaterial(color: .white, roughness: 1.0, isMetallic: false)]
        )
        
        // Position label above line
        textEntity.position = SIMD3<Float>(0, 0.1, 0)
        anchor.addChild(textEntity)
        
        arView.scene.addAnchor(anchor)
    }
    
    // Stop AR and motion tracking
    func stopSession() {
        arView.session.pause()
        motionManager.stopDeviceMotionUpdates()
        isSessionRunning = false
    }
    
    // Update current distance during measurement
    func updateCurrentWallLength() {
        guard scanMode == .scanning,
              let startPosition = currentWallStartPosition,
              let currentPosition = getCurrentCameraTransform()?.position else {
            return
        }
        
        let distance = simd_distance(startPosition, currentPosition)
        currentWallLength = distance
        
        // Update status with current distance
        if distance > 0.1 {
            sessionInfo = "Current distance: \(Int(distance * 100)) cm"
        }
    }
}

extension RoomScanManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update tracking state
        switch frame.camera.trackingState {
        case .normal:
            trackingState = "Tracking normal"
        case .notAvailable:
            trackingState = "Tracking not available"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                trackingState = "Limited: Move slower"
            case .insufficientFeatures:
                trackingState = "Limited: Point at textured surfaces"
            case .initializing:
                trackingState = "Initializing tracking..."
            case .relocalizing:
                trackingState = "Relocalizing..."
            @unknown default:
                trackingState = "Limited tracking"
            }
        }
        
        // Update current distance during measurement
        if scanMode == .scanning {
            updateCurrentWallLength()
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionInfo = "AR Session error - please restart app"
    }
}