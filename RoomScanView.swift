import SwiftUI
import ARKit
import RealityKit

struct RoomScanView: View {
    @StateObject private var scanManager = RoomScanManager()
    @State private var showingResetConfirmation = false
    @State private var showingTutorial = true
    
    var body: some View {
        ZStack {
            if scanManager.isARSupported && scanManager.isMotionAvailable {
                ARViewContainer(scanManager: scanManager)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Status bar at top
                    statusBar
                    
                    Spacer()
                    
                    // Scanning prompt
                    scanPromptView
                    
                    Spacer()
                    
                    // Controls at bottom
                    controlBar
                }
                .alert(isPresented: $showingResetConfirmation) {
                    Alert(
                        title: Text("Reset Room Scan"),
                        message: Text("This will delete all walls and start a new scan. Are you sure?"),
                        primaryButton: .destructive(Text("Reset")) {
                            scanManager.resetScan()
                        },
                        secondaryButton: .cancel()
                    )
                }
            } else {
                // Fallback view when device doesn't support required capabilities
                unsupportedDeviceView
            }
            
            // Tutorial overlay
            if showingTutorial {
                tutorialOverlay
            }
        }
        .onAppear {
            scanManager.setupARSession()
        }
        .onDisappear {
            scanManager.stopSession()
        }
    }
    
    var statusBar: some View {
        HStack {
            Text("Walls: \(scanManager.wallCount)")
                .bold()
            
            Spacer()
            
            if !scanManager.trackingState.isEmpty {
                Label(scanManager.trackingState, systemImage: "camera.viewfinder")
                    .font(.footnote)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
    }
    
    var scanPromptView: some View {
        VStack(spacing: 10) {
            Text(scanManager.scanPrompt)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if scanManager.scanMode == .scanning {
                HStack {
                    Text("Current length:")
                    Text(String(format: "%.2f m", scanManager.currentWallLength))
                        .bold()
                }
                
                // Visual indicator for steady positioning
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    .scaleEffect(1.5)
            }
            
            if scanManager.scanMode == .completed {
                VStack(spacing: 6) {
                    Text("Room area: \(String(format: "%.2f", scanManager.roomModel.roomArea)) m²")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.green)
                    
                    Text(scanManager.roomModel.getRoomDimensions())
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(backgroundColorForMode)
        .cornerRadius(10)
        .foregroundColor(.white)
        .padding()
    }
    
    var controlBar: some View {
        HStack {
            Button(action: {
                showingResetConfirmation = true
            }) {
                Label("Reset", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Spacer()
            
            // Help button
            Button(action: {
                showingTutorial = true
            }) {
                Label("Help", systemImage: "questionmark.circle")
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    var backgroundColorForMode: Color {
        switch scanManager.scanMode {
        case .waiting:
            return Color.blue.opacity(0.7)
        case .scanning:
            return Color.green.opacity(0.7)
        case .connecting:
            return Color.orange.opacity(0.7)
        case .completed:
            return Color.purple.opacity(0.7)
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
                Text("This device does not support ARKit with world tracking, which is required for room scanning.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            if !scanManager.isMotionAvailable {
                Text("This device does not have the required motion sensors for room scanning.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Text("Please try using a newer device with AR capabilities.")
                .italic()
                .padding(.top)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(30)
    }
    
    var tutorialOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showingTutorial = false
                }
            
            VStack(spacing: 30) {
                Text("How to Scan a Room")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 20) {
                    tutorialStep(number: 1, text: "Place your phone flat against a wall and hold steady for a moment")
                    tutorialStep(number: 2, text: "Move along the wall while keeping the phone pressed against it")
                    tutorialStep(number: 3, text: "When you reach the end of the wall, pull the phone away")
                    tutorialStep(number: 4, text: "Move to the next wall and repeat until you complete the room")
                }
                
                Button(action: {
                    showingTutorial = false
                }) {
                    Text("Got it!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(minWidth: 200)
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
    
    func tutorialStep(number: Int, text: String) -> some View {
        HStack(alignment: .top) {
            Text("\(number)")
                .font(.title2)
                .bold()
                .frame(width: 36, height: 36)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
            
            Text(text)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    var scanManager: RoomScanManager
    
    func makeUIView(context: Context) -> ARView {
        return scanManager.arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Nothing to update
    }
}