import Foundation
import SwiftUI
import Combine
import AVFoundation

// ViewModel for the wall scanning app
class WallScanViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Room model and scan state
    @Published var roomModel = RoomModel()
    @Published var isScanning = false
    
    // UI state
    @Published var statusMessage = "Ready to scan"
    @Published var canvasScale: CGFloat = 5.0
    @Published var showDebugInfo = true
    @Published var motionData = "No motion data yet"
    @Published var locationData = "No location data yet"
    
    // MARK: - Private Properties
    
    // Core scanning engine
    private let scanManager = WallScanManager()
    
    // Feedback generators
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Audio player for sound cues
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Initialization
    
    init() {
        setupScanManager()
        setupAudioPlayer()
        prepareHaptics()
    }
    
    // MARK: - Public Methods
    
    // Start the scanning process
    func startScanning() {
        resetAccelerationBuffer()
        isScanning = true
        scanManager.startScanning()
    }
    
    // Stop the scanning process
    func stopScanning() {
        isScanning = false
        scanManager.stopScanning()
        
        // Process results if we have enough data
        if roomModel.wallPoints.count >= 3 {
            notificationFeedback.notificationOccurred(.success)
            statusMessage = "Room processed: \(roomModel.formattedArea()) area, \(roomModel.formattedPerimeter()) perimeter"
        } else {
            notificationFeedback.notificationOccurred(.warning)
            statusMessage = "Not enough walls to form a room"
        }
    }
    
    // Toggle scanning state
    func toggleScan() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    // Reset everything
    func resetScan() {
        if isScanning {
            scanManager.stopScanning()
        }
        
        isScanning = false
        roomModel.reset()
        resetAccelerationBuffer()
        statusMessage = "Ready to scan"
    }
    
    // Toggle room closure
    func toggleRoomClosure() {
        roomModel.isClosed.toggle()
        
        if roomModel.isClosed {
            notificationFeedback.notificationOccurred(.success)
        } else {
            notificationFeedback.notificationOccurred(.warning)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupScanManager() {
        // Set up callbacks from the scan manager
        scanManager.onStatusUpdate = { [weak self] status in
            DispatchQueue.main.async {
                self?.statusMessage = status
            }
        }
        
        scanManager.onWallDetected = { [weak self] wallPoint in
            DispatchQueue.main.async {
                self?.handleWallDetection(wallPoint)
            }
        }
    }
    
    private func handleWallDetection(_ wallPoint: WallPoint) {
        // Play haptic feedback
        impactFeedback.impactOccurred()
        
        // Play audio cue
        audioPlayer?.play()
        
        // Add the wall point to our model
        roomModel.addWallPoint(wallPoint)
        
        // Update the UI
        statusMessage = "Wall \(roomModel.wallPoints.count) recorded"
    }
    
    private func resetAccelerationBuffer() {
        // This is now handled by the scan manager
    }
    
    private func prepareHaptics() {
        impactFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    private func setupAudioPlayer() {
        // Use a system sound as a fallback since we don't have custom audio files
        let systemSoundID: SystemSoundID = 1104 // Standard system sound
        AudioServicesPlaySystemSound(systemSoundID)
        
        // For a real app, load a custom audio file as shown here:
        /*
        guard let url = Bundle.main.url(forResource: "wall_touch", withExtension: "wav") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Error loading audio file: \(error)")
        }
        */
    }
}