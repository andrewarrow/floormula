import ARKit
import Combine
import RealityKit

class ARManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var sessionInfo = ""
    @Published var planeDetectionStatus = "No planes detected"
    @Published var trackingState: String = "Initializing"
    
    let arView = ARView(frame: .zero)
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupARSession()
    }
    
    func setupARSession() {
        print("DEBUG: Setting up AR session with enhanced debugging")
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Disable environment texturing to reduce flickering and resource usage
        configuration.environmentTexturing = .none
        
        // Reset tracking when restarting session to fix initialization issues
        configuration.isAutoFocusEnabled = true
        configuration.worldAlignment = .gravity
        
        // If available on the device, enable more stable tracking features
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            print("DEBUG: Device supports person segmentation - disabling to improve performance")
            // Don't enable these features as they can cause resource issues
        }
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            print("DEBUG: Device supports scene reconstruction - disabling to improve performance")
            // Don't enable these features as they can cause resource issues
        }
        
        arView.session.delegate = self
        arView.automaticallyConfigureSession = false
        
        // Configure debug options to help diagnose tracking issues
        #if DEBUG
        arView.debugOptions = [.showFeaturePoints]
        print("DEBUG: Enabled feature points visualization for debugging")
        #endif
        
        // Reset tracking state entirely to fix initialization
        print("DEBUG: Resetting AR tracking state")
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Log camera settings to help debug tracking quality
        if let camera = arView.session.currentFrame?.camera {
            print("DEBUG: Camera intrinsics: \(camera.intrinsics)")
            print("DEBUG: Camera transform: \(camera.transform)")
            print("DEBUG: Initial tracking state: \(String(describing: camera.trackingState))")
        } else {
            print("DEBUG: No camera frame available yet")
        }
        
        isSessionRunning = true
        print("DEBUG: AR session started")
    }
    
    func stopARSession() {
        arView.session.pause()
        isSessionRunning = false
    }
}

extension ARManager: ARSessionDelegate {
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
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let planeAnchors = anchors.compactMap { $0 as? ARPlaneAnchor }
        if !planeAnchors.isEmpty {
            let horizontalCount = planeAnchors.filter { $0.alignment == .horizontal }.count
            let verticalCount = planeAnchors.filter { $0.alignment == .vertical }.count
            planeDetectionStatus = "Planes detected: \(horizontalCount) horizontal, \(verticalCount) vertical"
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
