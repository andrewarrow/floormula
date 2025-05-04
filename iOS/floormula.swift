import SwiftUI
import ARKit
import RealityKit
import CoreMotion

@main
struct floormulaApp: App {
    init() {
        print("Room Measurement App initializing")
        
        // Pre-warm RealityKit to avoid runtime shader compilation errors
        let _ = try? RealityKit.Entity()
        
        // Check availability of required features
        if !ARWorldTrackingConfiguration.isSupported {
            print("ARKit with world tracking is not supported on this device")
        }
        
        if !CMMotionManager().isDeviceMotionAvailable {
            print("Device motion is not available on this device")
        }
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}