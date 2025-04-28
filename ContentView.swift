import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SensorContentView()
                .tabItem {
                    Label("Sensors", systemImage: "speedometer")
                }
            
            ARContentView()
                .tabItem {
                    Label("AR", systemImage: "camera.viewfinder")
                }
            
            LocationContentView()
                .tabItem {
                    Label("Location", systemImage: "location")
                }
        }
    }
}
