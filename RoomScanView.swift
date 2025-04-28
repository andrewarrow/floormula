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
        VStack(spacing: 4) {
            HStack {
                Text("Walls: \(scanManager.wallCount)")
                    .bold()
                
                Spacer()
                
                if !scanManager.trackingState.isEmpty {
                    Label(scanManager.trackingState, systemImage: "camera.viewfinder")
                        .font(.footnote)
                }
            }
            
            // Debug info
            if !scanManager.sessionInfo.isEmpty {
                Text(scanManager.sessionInfo)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
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
                    Text("Measuring distance:")
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
                Text("How to Measure a Room")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 20) {
                    tutorialStep(number: 1, text: "Hold phone flat against one wall until you see \"FIRST POINT CAPTURED!\"")
                    tutorialStep(number: 2, text: "A green dot will mark your starting position")
                    tutorialStep(number: 3, text: "Walk straight across to the opposite wall and hold phone against it")
                    tutorialStep(number: 4, text: "When you see red dot and blue line, measurement is complete")
                    tutorialStep(number: 5, text: "Repeat with remaining walls to complete the room (at least 4 walls total)")
                }
                
                VStack(spacing: 12) {
                    Text("Visual Indicators:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        HStack { 
                            Circle().fill(Color.green).frame(width: 12, height: 12)
                            Text("First point").foregroundColor(.white)
                        }
                        
                        HStack { 
                            Circle().fill(Color.red).frame(width: 12, height: 12) 
                            Text("Second point").foregroundColor(.white)
                        }
                        
                        HStack { 
                            Rectangle().fill(Color.blue).frame(width: 20, height: 4) 
                            Text("Measurement").foregroundColor(.white)
                        }
                    }
                    .font(.footnote)
                }
                
                Button(action: {
                    showingTutorial = false
                }) {
                    Text("Start Measuring")
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