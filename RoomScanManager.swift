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
    @Published var scanPrompt: String = "Place phone flat against a wall to begin measuring"
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
    
    private var accelerometerThreshold: Double = 0.08  // Increased for more tolerance
    private var steadyDurationThreshold: TimeInterval = 0.8  // Reduced for faster response
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
            // Log motion information to help debug positioning issues
            if self.scanMode == .scanning && self.steadyStartTime == nil {
                // Show current distance to help guide user
                if let start = self.currentWallStartPosition, 
                   let current = self.getCurrentCameraTransform()?.position {
                    let distance = simd_distance(start, current)
                    if distance < 0.1 {
                        self.sessionInfo = "⚠️ You haven't moved far enough. Walk to opposite wall."
                    } else {
                        self.sessionInfo = "Distance: \(String(format: "%.2f", distance))m - Now hold phone against opposite wall"
                    }
                }
            }
            
            if isNearlyStationary {
                if self.steadyStartTime == nil {
                    self.steadyStartTime = Date()
                    if self.scanMode == .waiting {
                        self.sessionInfo = "Holding steady on FIRST wall... keep still"
                    } else if self.scanMode == .scanning {
                        self.sessionInfo = "Holding steady on SECOND wall... keep still"
                        
                        // Check if we've moved far enough before finalizing
                        if let start = self.currentWallStartPosition, 
                           let current = self.getCurrentCameraTransform()?.position {
                            let distance = simd_distance(start, current)
                            if distance < 0.1 {
                                self.sessionInfo = "⚠️ TOO CLOSE to starting point! Move to opposite wall first."
                                self.steadyStartTime = nil  // Reset timer - don't allow this measurement
                                return
                            }
                        }
                    }
                } else {
                    let steadyDuration = Date().timeIntervalSince(self.steadyStartTime!)
                    let remainingTime = max(0, self.steadyDurationThreshold - steadyDuration)
                    
                    if self.scanMode == .waiting {
                        self.sessionInfo = String(format: "Keep holding against FIRST wall: %.1f seconds", remainingTime)
                    } else {
                        self.sessionInfo = String(format: "Keep holding against SECOND wall: %.1f seconds", remainingTime)
                    }
                    
                    if steadyDuration >= self.steadyDurationThreshold {
                        if self.scanMode == .waiting {
                            // Phone has been held steady against first wall for required duration
                            self.sessionInfo = "First wall position captured!"
                            self.beginWallDetection()
                        } else if self.scanMode == .scanning {
                            // Phone has been held steady against second wall
                            self.sessionInfo = "Second wall position captured!"
                            self.endWallDetection()
                        }
                    }
                }
            } else {
                if self.steadyStartTime != nil {
                    if self.scanMode == .waiting {
                        self.sessionInfo = "Movement detected. Hold phone still against FIRST wall."
                    } else {
                        self.sessionInfo = "Movement detected. Hold phone still against SECOND wall."
                    }
                }
                self.steadyStartTime = nil
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
        scanPrompt = "FIRST POINT CAPTURED! Now move to opposite wall and hold phone against it"
        detectingWall = true
        currentWallStartPosition = cameraTransform.position
        
        // Provide haptic feedback
        playHapticFeedback(intensity: 0.8, sharpness: 0.5)
        
        // Visualize the start point
        addSphereAnchor(at: cameraTransform.position, color: .green)
        
        sessionInfo = "Green dot = starting point. Now walk to opposite wall."
        print("DEBUG: First point captured at position \(cameraTransform.position)")
        
        // Force update the current wall length to zero to start fresh
        currentWallLength = 0.0
        
        // Add additional debug info about expected end behavior
        print("DEBUG: AR tracking quality: \(arView.session.currentFrame?.camera.trackingState ?? .notAvailable)")
        print("DEBUG: Waiting for user to move phone to second position...")
    }
    
    private func endWallDetection() {
        guard let currentWallStartPosition = currentWallStartPosition,
              let currentCameraPosition = getCurrentCameraTransform()?.position,
              let currentWallNormal = currentWallNormal else {
            scanMode = .waiting
            scanPrompt = "Place phone flat against a wall to begin measuring"
            sessionInfo = "Error: Missing position data. Try again."
            detectingWall = false
            return
        }
        
        // Calculate the wall length (distance between the two points)
        let distance = simd_distance(currentWallStartPosition, currentCameraPosition)
        
        // Debug starting and ending positions to help diagnose distance issues
        print("DEBUG: Starting position = \(currentWallStartPosition)")
        print("DEBUG: Ending position = \(currentCameraPosition)")
        print("DEBUG: Measured distance = \(distance)m between points")
        
        if distance > 0.1 { // Reduced minimum to 10cm to help with testing
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
            scanPrompt = "SUCCESS! Measured \(String(format: "%.2f", distance))m"
            sessionInfo = "Green dot = first point, Red dot = second point, Blue line = measurement"
            
            // Check if room is complete
            if roomModel.isRoomClosed() {
                scanMode = .completed
                scanPrompt = "Room scan complete! Area: \(String(format: "%.2f", roomModel.roomArea))m²"
                sessionInfo = "All walls measured successfully!"
                playHapticFeedback(intensity: 1.0, sharpness: 0.7)
            } else {
                scanMode = .connecting
                scanPrompt = "Ready for next wall. Place phone against another wall"
                sessionInfo = "Measure another wall. You need at least 4 walls for a complete room."
            }
        } else {
            // If measurement failed, add debug visualization anyway to help diagnose the issue
            addSphereAnchor(at: currentCameraPosition, color: .orange) // Orange for failed measurements
            
            // Draw a dotted line to show the attempted measurement
            let anchor = AnchorEntity()
            anchor.position = SIMD3<Float>((currentWallStartPosition + currentCameraPosition) / 2)
            
            // Create a text entity showing the exact distance
            let textMesh = MeshResource.generateText(
                "Failed: \(String(format: "%.2f", distance))m",
                extrusionDepth: 0.01,
                font: .boldSystemFont(ofSize: 0.05),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            let textEntity = ModelEntity(mesh: textMesh, materials: [SimpleMaterial(color: .red, roughness: 0.5, isMetallic: false)])
            textEntity.position = SIMD3<Float>(0, 0.1, 0)
            anchor.addChild(textEntity)
            arView.scene.addAnchor(anchor)
            
            scanMode = .waiting
            scanPrompt = "MEASUREMENT TOO SHORT. Need at least 10cm distance."
            sessionInfo = "Try again. Current distance: \(String(format: "%.2f", distance*100))cm"
            
            print("DEBUG: Failed measurement - distance too short (\(distance)m)")
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
        scanPrompt = "Place phone flat against a wall to begin measuring"
        sessionInfo = "RESET: Start by holding phone flat against a wall"
        
        // Remove all anchors from the scene
        arView.scene.anchors.removeAll()
        
        // Light haptic feedback
        playHapticFeedback(intensity: 0.3, sharpness: 0.3)
        
        print("DEBUG: Room scan reset, all walls cleared")
    }
    
    private func addSphereAnchor(at position: simd_float3, color: UIColor) {
        // Create a larger, more visible sphere
        let anchor = AnchorEntity(world: SIMD3<Float>(position))
        let mesh = MeshResource.generateSphere(radius: 0.08)  // Bigger radius
        let material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: true)
        let sphere = ModelEntity(mesh: mesh, materials: [material])
        
        // Add a label to describe what this point is
        let text = color == .green ? "Start" : "End"
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.05),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let textMaterial = SimpleMaterial(color: .white, roughness: 0.5, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = SIMD3<Float>(0, 0.12, 0)  // Position text above sphere
        
        anchor.addChild(sphere)
        anchor.addChild(textEntity)
        arView.scene.addAnchor(anchor)
        
        print("DEBUG: Added \(text) point marker at \(position)")
    }
    
    private func addLineAnchor(from start: simd_float3, to end: simd_float3) {
        // Create a line between two points
        let anchor = AnchorEntity()
        
        // Calculate the midpoint
        let midpoint = (start + end) / 2
        
        // Calculate the distance between points
        let distance = simd_distance(start, end)
        
        // Create a more visible cylinder shape that spans between the points
        let mesh = MeshResource.generateCylinder(height: distance, radius: 0.03)  // Thicker line
        let material = SimpleMaterial(color: .blue, roughness: 0.5, isMetallic: true)  // More visible material
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
        
        // Add text label for wall length with better visibility
        let measurementText = "\(String(format: "%.2f", distance))m"
        let textMesh = MeshResource.generateText(
            measurementText,
            extrusionDepth: 0.02,
            font: .boldSystemFont(ofSize: 0.12),  // Larger, bold text
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        // Brighter text with background for better visibility
        let textMaterial = SimpleMaterial(color: .yellow, roughness: 0.3, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        
        // Add a background panel behind the text for better visibility
        let textBackground = ModelEntity(
            mesh: MeshResource.generatePlane(width: Float(measurementText.count) * 0.07, height: 0.15),
            materials: [SimpleMaterial(color: UIColor.darkGray.withAlphaComponent(0.7), roughness: 1.0, isMetallic: false)]
        )
        textBackground.position = SIMD3<Float>(0, 0, -0.01)  // Slightly behind the text
        textEntity.addChild(textBackground)
        
        // Position the text above the line
        let textOffset = simd_normalize(simd_cross(direction, simd_float3(0, 1, 0))) * 0.15
        textEntity.position = SIMD3<Float>(0, 0.15, 0) + textOffset  // Positioned higher above the line
        
        // Billboard effect - always face the camera
        textEntity.orientation = rotation
        
        anchor.addChild(textEntity)
        
        print("DEBUG: Added measurement line of \(distance)m between points")
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
        
        // Calculate and update the current distance between start and current position
        let newWallLength = simd_distance(startPosition, currentPosition)
        currentWallLength = newWallLength
        
        // Update session info with current measurement
        if newWallLength > 0.05 {
            sessionInfo = "Current distance: \(String(format: "%.2f", newWallLength))m"
            
            // Periodically log distance to debug console to help track movement
            if Int(newWallLength * 100) % 20 == 0 { // Log every ~20cm of movement
                print("DEBUG: Current distance during measurement: \(newWallLength)m")
            }
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
            
            // Also periodically check if we've moved far enough to consider successful
            // This helps users see when they've moved far enough for a valid measurement
            if let startPosition = currentWallStartPosition,
               let currentPosition = getCurrentCameraTransform()?.position {
                let distance = simd_distance(startPosition, currentPosition)
                
                // If we've moved more than 1 meter, provide encouraging feedback
                if distance > 1.0 {
                    playHapticFeedback(intensity: 0.3, sharpness: 0.3) // Light feedback
                    sessionInfo = "Good distance! (\(String(format: "%.2f", distance))m) - You can hold steady against wall now"
                }
            }
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