import SwiftUI
import ARKit
import RealityKit

struct RoomScanView: View {
    @StateObject private var scanManager = RoomScanManager()
    @State private var showingHelp = false
    
    var body: some View {
        ZStack {
            if scanManager.isARSupported && scanManager.isMotionAvailable {
                ARViewContainer(scanManager: scanManager)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Measurement display
                    measurementDisplay
                    
                    Spacer()
                    
                    // Bottom controls
                    controlBar
                }
            } else {
                // Fallback view when device doesn't support required capabilities
                unsupportedDeviceView
            }
            
            // Help overlay
            if showingHelp {
                helpOverlay
            }
        }
        .onAppear {
            scanManager.setupARSession()
        }
        .onDisappear {
            scanManager.stopSession()
        }
    }
    
    var measurementDisplay: some View {
        VStack(spacing: 20) {
            // Width and Length measurements
            HStack(spacing: 40) {
                // Width
                VStack {
                    Text("WIDTH")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(Int(scanManager.roomModel.getRoomWidth() * 100))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("cm")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(minWidth: 120)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.7))
                .cornerRadius(12)
                
                // Length
                VStack {
                    Text("LENGTH")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(Int(scanManager.roomModel.getRoomLength() * 100))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("cm")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(minWidth: 120)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.7))
                .cornerRadius(12)
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(16)
            .padding(.top, 60)
            
            // Status and instructions text
            if !scanManager.sessionInfo.isEmpty {
                Text(scanManager.sessionInfo)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    var controlBar: some View {
        HStack(spacing: 20) {
            // Reset button
            Button(action: {
                scanManager.resetScan()
            }) {
                VStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 24))
                    Text("Reset")
                        .font(.caption)
                }
                .frame(width: 60, height: 60)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(30)
            }
            
            // Main action button
            Button(action: {
                if scanManager.scanMode == .waiting || scanManager.scanMode == .connecting {
                    // Start the measurement process
                    scanManager.beginWallDetection()
                } else if scanManager.scanMode == .scanning {
                    // Complete the measurement
                    scanManager.endWallDetection()
                }
            }) {
                Text(actionButtonText)
                    .font(.headline)
                    .frame(width: 180, height: 60)
                    .background(actionButtonColor)
                    .foregroundColor(.white)
                    .cornerRadius(30)
            }
            
            // Help button
            Button(action: {
                showingHelp = true
            }) {
                VStack {
                    Image(systemName: "questionmark")
                        .font(.system(size: 24))
                    Text("Help")
                        .font(.caption)
                }
                .frame(width: 60, height: 60)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(30)
            }
        }
        .padding(.bottom, 30)
    }
    
    var actionButtonText: String {
        switch scanManager.scanMode {
        case .waiting, .connecting:
            return "Measure Wall"
        case .scanning:
            return "Capture Distance"
        case .completed:
            return "Add Wall"
        }
    }
    
    var actionButtonColor: Color {
        switch scanManager.scanMode {
        case .waiting, .connecting:
            return .blue
        case .scanning:
            return .green
        case .completed:
            return .purple
        }
    }
    
    var unsupportedDeviceView: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("Unsupported Device")
                .font(.title)
                .bold()
            
            if !scanManager.isARSupported {
                Text("This device does not support ARKit, which is required for room measurements.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            if !scanManager.isMotionAvailable {
                Text("This device does not have the required motion sensors.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(30)
    }
    
    var helpOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showingHelp = false
                }
            
            VStack(spacing: 20) {
                Text("How to Measure a Room")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 16) {
                    helpStep(number: 1, text: "Press 'Measure Wall' button")
                    helpStep(number: 2, text: "Place your phone against the first wall")
                    helpStep(number: 3, text: "Walk to the opposite wall")
                    helpStep(number: 4, text: "Place your phone against the second wall")
                    helpStep(number: 5, text: "Press 'Capture Distance' to measure")
                }
                
                Text("Tip: For best results, keep your phone flat against the walls and move in a straight line between measurements.")
                    .font(.callout)
                    .foregroundColor(.yellow)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    showingHelp = false
                }) {
                    Text("Got It")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top)
            }
            .padding(30)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(16)
            .padding(30)
        }
    }
    
    func helpStep(number: Int, text: String) -> some View {
        HStack(alignment: .top) {
            Text("\(number)")
                .font(.title2)
                .bold()
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
            
            Text(text)
                .foregroundColor(.white)
                .font(.headline)
            
            Spacer()
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    var scanManager: RoomScanManager
    
    func makeUIView(context: Context) -> ARView {
        let view = scanManager.arView
        
        // Set rendering options for better performance
        view.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        view.environment.sceneUnderstanding.options = []
        
        // Enable feature points visualization to help with tracking
        view.debugOptions = [.showFeaturePoints]
        
        return view
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Nothing to update here
    }
}