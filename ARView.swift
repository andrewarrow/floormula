import SwiftUI
import ARKit
import RealityKit

struct ARContentView: View {
    @StateObject private var arManager = ARManager()
    
    var body: some View {
        ZStack {
            OldARViewContainer(arManager: arManager)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("AR Status")
                        .font(.headline)
                    
                    HStack {
                        Text("Tracking:")
                        Text(arManager.trackingState)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Planes:")
                        Text(arManager.planeDetectionStatus)
                            .foregroundColor(.primary)
                    }
                    
                    if !arManager.sessionInfo.isEmpty {
                        HStack {
                            Text("Info:")
                            Text(arManager.sessionInfo)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .foregroundColor(.white)
                .padding()
            }
        }
        .onAppear {
            arManager.setupARSession()
        }
        .onDisappear {
            arManager.stopARSession()
        }
    }
}

struct OldARViewContainer: UIViewRepresentable {
    var arManager: ARManager
    
    func makeUIView(context: Context) -> ARView {
        return arManager.arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}