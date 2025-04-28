import ARKit
import Combine
import RealityKit
import CoreMotion
import CoreHaptics
import simd

enum ScanMode {
    case waiting       // Waiting for user to place phone on wall
    case scanning      // In process of detecting a wall
    case connecting    // Moving between walls
    case completed     // Room scan is complete
}

class RoomScanManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var sessionInfo = ""
    @Published var trackingState: String = "Initializing"
    @Published var scanMode: ScanMode = .waiting
    @Published var scanPrompt: String = "Place phone flat against a wall to begin scanning"
    @Published var wallCount: Int = 0
    @Published var currentWallLength: Float = 0.0
    @Published var detectingWall: Bool = false
    @Published var isARSupported: Bool = true
    @Published var isMotionAvailable: Bool = true
    
    let arView = ARView(frame: .zero)
    let motionManager = CMMotionManager()
    let roomModel = RoomModel()
    
    private var cancellables = Set<AnyCancellable>()
    private var wallDetectionTimer: Timer?
    private var lastWallPosition: simd_float3?
    private var currentWallStartPosition: simd_float3?
    private var currentWallNormal: simd_float3?
    private var queue = OperationQueue()
    private var hapticEngine: CHHapticEngine?
    
    private var accelerometerThreshold: Double = 0.05
    private var steadyDurationThreshold: TimeInterval = 1.0
    private var steadyStartTime: Date?
    
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
        // Check ARKit support
        isARSupported = ARWorldTrackingConfiguration.isSupported
        
        // Check motion sensors
        isMotionAvailable = motionManager.isDeviceMotionAvailable && 
                           motionManager.isAccelerometerAvailable
        
        if !isARSupported {
            sessionInfo = "ARKit world tracking not supported on this device"
        }
        
        if !isMotionAvailable {
            sessionInfo = "Required motion sensors not available on this device"
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
        configuration.environmentTexturing = .automatic
        
        arView.session.delegate = self
        arView.automaticallyConfigureSession = false
        arView.session.run(configuration)
        
        isSessionRunning = true
    }
    
    func setupMotionManager() {
        guard isMotionAvailable else { return }
        
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, error in
                guard let self = self, let data = data, error == nil else { return }
                self.processAccelerometerData(data)
            }
        }
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
                guard let self = self, let motion = motion, error == nil else { return }
                self.processDeviceMotion(motion)
            }
        }
    }
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        // Only process in waiting or scanning mode
        guard scanMode == .waiting || scanMode == .scanning else {
            steadyStartTime = nil
            return
        }
        
        // Check if phone is steady against a surface
        let accelerationMagnitude = sqrt(
            pow(data.acceleration.x, 2) +
            pow(data.acceleration.y, 2) +
            pow(data.acceleration.z, 2)
        )
        
        // Check if acceleration is close to 1G (gravity only, minimal movement)
        let isNearlyStationary = abs(accelerationMagnitude - 1.0) < accelerometerThreshold
        
        DispatchQueue.main.async {
            if isNearlyStationary {
                if self.steadyStartTime == nil {
                    self.steadyStartTime = Date()
                } else if Date().timeIntervalSince(self.steadyStartTime!) >= self.steadyDurationThreshold {
                    if self.scanMode == .waiting {
                        // Phone has been held steady against a wall for required duration
                        self.beginWallDetection()
                    }
                }
            } else {
                self.steadyStartTime = nil
                if self.scanMode == .scanning {
                    // Phone moved from wall
                    self.endWallDetection()
                }
            }
        }
    }
    
    private func processDeviceMotion(_ motion: CMDeviceMotion) {
        // Use device gravity vector to determine wall orientation
        // This helps us determine which direction the wall faces
        guard scanMode == .scanning else { return }
        
        let gravity = motion.gravity
        
        // Transform gravity vector to ARKit coordinate space
        let normalVector = simd_float3(
            Float(-gravity.x),
            Float(-gravity.y),
            Float(-gravity.z)
        )
        
        DispatchQueue.main.async {
            self.currentWallNormal = normalVector
        }
    }
    
    private func beginWallDetection() {
        guard let cameraTransform = getCurrentCameraTransform() else { return }
        
        scanMode = .scanning
        scanPrompt = "Hold phone against wall and move along its length"
        detectingWall = true
        currentWallStartPosition = cameraTransform.position
        
        // Provide haptic feedback
        playHapticFeedback(intensity: 0.8, sharpness: 0.5)
        
        // Visualize the start point
        addSphereAnchor(at: cameraTransform.position, color: .green)
    }
    
    private func endWallDetection() {
        guard let currentWallStartPosition = currentWallStartPosition,
              let currentCameraPosition = getCurrentCameraTransform()?.position,
              let currentWallNormal = currentWallNormal else {
            scanMode = .waiting
            scanPrompt = "Place phone flat against a wall to begin scanning"
            detectingWall = false
            return
        }
        
        // Only add walls with meaningful length
        let distance = simd_distance(currentWallStartPosition, currentCameraPosition)
        if distance > 0.3 { // Minimum 30cm to be considered a wall
            // Add wall to room model
            roomModel.addWall(
                startPoint: currentWallStartPosition,
                endPoint: currentCameraPosition,
                normalVector: currentWallNormal
            )
            
            // Visualize the end point and add strong haptic feedback
            addSphereAnchor(at: currentCameraPosition, color: .red)
            addLineAnchor(from: currentWallStartPosition, to: currentCameraPosition)
            playHapticFeedback(intensity: 1.0, sharpness: 1.0)
            
            wallCount += 1
            scanPrompt = "Wall \(wallCount) recorded (\(String(format: "%.2f", distance))m)"
            
            // Check if room is complete
            if roomModel.isRoomClosed() {
                scanMode = .completed
                scanPrompt = "Room scan complete! Area: \(String(format: "%.2f", roomModel.roomArea))m²"
                playHapticFeedback(intensity: 1.0, sharpness: 0.7)
            } else {
                scanMode = .connecting
                scanPrompt = "Move to next wall and place phone against it"
            }
        } else {
            scanMode = .waiting
            scanPrompt = "Wall too short. Try again."
        }
        
        detectingWall = false
        self.currentWallStartPosition = nil
        self.currentWallLength = 0.0
    }
    
    private func getCurrentCameraTransform() -> (position: simd_float3, orientation: simd_quatf)? {
        guard let frame = arView.session.currentFrame else { return nil }
        let transform = frame.camera.transform
        let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let orientation = simd_quatf(transform)
        return (position, orientation)
    }
    
    func resetScan() {
        roomModel.clear()
        wallCount = 0
        scanMode = .waiting
        scanPrompt = "Place phone flat against a wall to begin scanning"
        
        // Remove all anchors from the scene
        arView.scene.anchors.removeAll()
        
        // Light haptic feedback
        playHapticFeedback(intensity: 0.3, sharpness: 0.3)
    }
    
    private func addSphereAnchor(at position: simd_float3, color: UIColor) {
        let anchor = AnchorEntity(world: SIMD3<Float>(position))
        let mesh = MeshResource.generateSphere(radius: 0.05)
        let material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: true)
        let sphere = ModelEntity(mesh: mesh, materials: [material])
        anchor.addChild(sphere)
        arView.scene.addAnchor(anchor)
    }
    
    private func addLineAnchor(from start: simd_float3, to end: simd_float3) {
        // Create a line between two points
        let anchor = AnchorEntity()
        
        // Calculate the midpoint
        let midpoint = (start + end) / 2
        
        // Calculate the distance between points
        let distance = simd_distance(start, end)
        
        // Create a cylinder shape that spans between the points
        let mesh = MeshResource.generateCylinder(height: distance, radius: 0.02)
        let material = SimpleMaterial(color: .blue, roughness: 0.5, isMetallic: false)
        let cylinder = ModelEntity(mesh: mesh, materials: [material])
        
        // Position and rotate the cylinder
        cylinder.position = SIMD3<Float>(0, 0, 0)
        
        // Calculate the quaternion to rotate the cylinder
        let direction = simd_normalize(end - start)
        let defaultDirection = simd_float3(0, 1, 0) // Default cylinder orientation is along y-axis
        
        // Check if vectors are not nearly parallel or anti-parallel
        let dot = simd_dot(defaultDirection, direction)
        let rotationAxis: simd_float3
        
        if abs(abs(dot) - 1) < 0.0001 {
            // Vectors are nearly parallel or anti-parallel
            // Use an arbitrary perpendicular axis
            rotationAxis = simd_normalize(simd_float3(1, 0, 0))
        } else {
            rotationAxis = simd_normalize(simd_cross(defaultDirection, direction))
        }
        
        let rotationAngle = acos(simd_clamp(dot, -1.0, 1.0))
        let rotation = simd_quatf(angle: rotationAngle, axis: rotationAxis)
        
        cylinder.orientation = rotation
        
        anchor.position = SIMD3<Float>(midpoint)
        anchor.addChild(cylinder)
        arView.scene.addAnchor(anchor)
        
        // Add text label for wall length
        let textMesh = MeshResource.generateText(
            "\(String(format: "%.2f", distance))m",
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let textMaterial = SimpleMaterial(color: .white, roughness: 0.5, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        
        // Position the text above the line
        let textOffset = simd_cross(direction, simd_float3(0, 0, 1)) * 0.1
        textEntity.position = SIMD3<Float>(0, 0, 0) + textOffset
        textEntity.orientation = rotation
        
        anchor.addChild(textEntity)
    }
    
    func stopSession() {
        arView.session.pause()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopDeviceMotionUpdates()
        isSessionRunning = false
    }
    
    func updateCurrentWallLength() {
        guard scanMode == .scanning,
              let startPosition = currentWallStartPosition,
              let currentPosition = getCurrentCameraTransform()?.position else {
            currentWallLength = 0.0
            return
        }
        
        currentWallLength = simd_distance(startPosition, currentPosition)
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
                trackingState = "Limited: Excessive motion"
            case .insufficientFeatures:
                trackingState = "Limited: Insufficient features"
            case .initializing:
                trackingState = "Limited: Initializing"
            case .relocalizing:
                trackingState = "Limited: Relocalizing"
            @unknown default:
                trackingState = "Limited: Unknown"
            }
        }
        
        // Update current wall length when scanning
        if scanMode == .scanning {
            updateCurrentWallLength()
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionInfo = "AR Session failed: \(error.localizedDescription)"
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        sessionInfo = "AR Session interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        sessionInfo = "AR Session interruption ended"
        setupARSession()
    }
}