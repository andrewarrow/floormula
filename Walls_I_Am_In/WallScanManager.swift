import Foundation
import CoreMotion
import ARKit
import CoreLocation
import UIKit

// WallScanManager - Core engine for wall scanning functionality
class WallScanManager: NSObject {
    // MARK: - Properties
    
    // Status callback
    var onStatusUpdate: ((String) -> Void)?
    
    // Wall detection callback
    var onWallDetected: ((WallPoint) -> Void)?
    
    // Scanning state
    private(set) var isScanning: Bool = false
    
    // Sensors
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    private let arSession = ARSession()
    
    // Impact detection parameters
    private let accelerationThreshold: Double = 1.2
    private let stabilityThreshold: Double = 0.08
    private let minimumTimeBetweenTouches: TimeInterval = 0.8
    private var lastTouchTime: Date = Date()
    
    // Sensor data buffers
    private var accelerationBuffer: [CMAcceleration] = []
    private var lastAcceleration: CMAcceleration?
    private var bufferSize = 15
    
    // Current position tracking
    private var lastHeading: Double = 0
    private var currentPosition = simd_float3(0, 0, 0)
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupLocationManager()
        configureARSession()
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard !isScanning else { return }
        
        isScanning = true
        resetSensorData()
        startSensors()
        onStatusUpdate?("Scanning started - touch walls to map")
    }
    
    func stopScanning() {
        guard isScanning else { return }
        
        isScanning = false
        stopSensors()
        onStatusUpdate?("Scanning stopped")
    }
    
    func reset() {
        stopScanning()
        resetSensorData()
        onStatusUpdate?("Scanner reset")
    }
    
    // MARK: - Private Methods
    
    private func resetSensorData() {
        accelerationBuffer.removeAll()
        lastAcceleration = nil
        lastTouchTime = Date()
        currentPosition = simd_float3(0, 0, 0)
    }
    
    private func startSensors() {
        // Start device motion updates
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.05
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let data = data else { return }
                self.processDeviceMotion(data)
            }
        }
        
        // Start accelerometer updates for impact detection
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.05
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let acceleration = data?.acceleration else { return }
                
                // Add to buffer for stability analysis
                self.accelerationBuffer.append(acceleration)
                if self.accelerationBuffer.count > self.bufferSize {
                    self.accelerationBuffer.removeFirst()
                }
                
                // Process for impact detection
                if self.isScanning {
                    self.detectWallImpact(acceleration)
                }
                
                // Store for next comparison
                self.lastAcceleration = acceleration
            }
        }
        
        // Start gyroscope updates for rotation
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.05
            motionManager.startGyroUpdates()
        }
        
        // Start location updates
        locationManager.startUpdatingHeading()
        
        // Start AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arSession.run(configuration)
    }
    
    private func stopSensors() {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        locationManager.stopUpdatingHeading()
        arSession.pause()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.headingFilter = 2.0
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func configureARSession() {
        arSession.delegate = self
    }
    
    private func processDeviceMotion(_ motion: CMDeviceMotion) {
        // Advanced sensor fusion would go here
        // This could integrate gravity, user acceleration, and attitude
    }
    
    private func detectWallImpact(_ acceleration: CMAcceleration) {
        let currentTime = Date()
        
        // Only check for impact if we have a previous reading and enough time has passed
        guard let lastAccel = lastAcceleration,
              currentTime.timeIntervalSince(lastTouchTime) > minimumTimeBetweenTouches else {
            return
        }
        
        // Calculate acceleration changes
        let deltaX = abs(acceleration.x - lastAccel.x)
        let deltaY = abs(acceleration.y - lastAccel.y)
        let deltaZ = abs(acceleration.z - lastAccel.z)
        let totalDelta = deltaX + deltaY + deltaZ
        
        // Impact detection based on:
        // 1. Significant change in acceleration (impact)
        // 2. Device stability after impact (against a wall)
        if totalDelta > accelerationThreshold && isStable() {
            lastTouchTime = currentTime
            handleWallDetection(with: acceleration)
        }
    }
    
    private func isStable() -> Bool {
        // Ensure we have enough data
        guard accelerationBuffer.count > 5 else { return false }
        
        // Check the most recent readings (post potential impact)
        let recentReadings = Array(accelerationBuffer.suffix(5))
        
        // Calculate variance
        var sumX = 0.0, sumY = 0.0, sumZ = 0.0
        for reading in recentReadings {
            sumX += reading.x
            sumY += reading.y
            sumZ += reading.z
        }
        
        let avgX = sumX / Double(recentReadings.count)
        let avgY = sumY / Double(recentReadings.count)
        let avgZ = sumZ / Double(recentReadings.count)
        
        var varianceSum = 0.0
        for reading in recentReadings {
            varianceSum += pow(reading.x - avgX, 2)
            varianceSum += pow(reading.y - avgY, 2)
            varianceSum += pow(reading.z - avgZ, 2)
        }
        
        let totalVariance = varianceSum / Double(recentReadings.count * 3)
        return totalVariance < stabilityThreshold
    }
    
    private func handleWallDetection(with acceleration: CMAcceleration) {
        // Provide haptic feedback (would be handled by the ViewModel)
        
        // Determine wall orientation based on impact
        let wallPoint = createWallPoint(from: acceleration)
        
        // Notify the parent system with the new wall point
        onWallDetected?(wallPoint)
        
        // Update status
        onStatusUpdate?("Wall touched")
    }
    
    private func createWallPoint(from acceleration: CMAcceleration) -> WallPoint {
        // Determine primary impact direction
        let absX = abs(acceleration.x)
        let absY = abs(acceleration.y)
        let absZ = abs(acceleration.z)
        
        var wallNormal = SIMD3<Float>(0, 0, 0)
        
        // Set normal vector based on dominant acceleration axis
        if absX > absY && absX > absZ {
            wallNormal.x = acceleration.x > 0 ? 1 : -1
        } else if absY > absX && absY > absZ {
            wallNormal.y = acceleration.y > 0 ? 1 : -1
        } else {
            wallNormal.z = acceleration.z > 0 ? 1 : -1
        }
        
        // Calculate position using heading and previous points
        var position: CGPoint
        
        if currentPosition == simd_float3(0, 0, 0) {
            // First point is origin
            position = CGPoint.zero
        } else {
            // Convert heading to radians
            let angleRadians = (lastHeading * .pi) / 180.0
            
            // Estimated distance (would be more accurate with ARKit spatial tracking)
            let distance: CGFloat = 2.0
            
            // Project the new position based on heading
            let dx = distance * CGFloat(cos(angleRadians))
            let dy = distance * CGFloat(sin(angleRadians))
            
            // Previous point position (simple 2D for this v1.0)
            let prevX = CGFloat(currentPosition.x)
            let prevY = CGFloat(currentPosition.z) // Using z for 2D y-axis in top-down view
            
            position = CGPoint(x: prevX + dx, y: prevY + dy)
            
            // Update the 3D position (would be more accurate with ARKit)
            currentPosition.x = Float(position.x)
            currentPosition.z = Float(position.y)
        }
        
        return WallPoint(
            position: position,
            orientation: wallNormal,
            heading: lastHeading,
            timestamp: Date()
        )
    }
}

// MARK: - Location Manager Delegate

extension WallScanManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastHeading = newHeading.trueHeading
    }
}

// MARK: - AR Session Delegate

extension WallScanManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // In a more advanced implementation, we would use the AR frame to:
        // 1. Get the current device position in world space
        // 2. Detect planes (walls) and refine our touch detection
        // 3. Enhance our room mapping with spatial awareness
    }
}