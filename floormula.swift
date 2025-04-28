import SwiftUI
import ARKit
import RealityKit
import CoreLocation
import CoreMotion

@main
struct floormulaApp: App {
    init() {
        // Register for any initial app setup
        print("floormulaApp initializing")
        
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
        }
    }
}