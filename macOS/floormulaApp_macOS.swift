import SwiftUI

@main
struct floormulaApp_macOS: App {
    init() {
        print("Room Measurement App for macOS initializing")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView_macOS()
                .preferredColorScheme(.dark)
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}