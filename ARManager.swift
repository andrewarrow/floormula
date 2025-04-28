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
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        arView.session.delegate = self
        arView.automaticallyConfigureSession = false
        arView.session.run(configuration)
        
        isSessionRunning = true
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
