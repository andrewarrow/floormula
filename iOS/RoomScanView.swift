import SwiftUI
import ARKit
import RealityKit

struct RoomScanView: View {
    @StateObject private var scanManager = RoomScanManager()
    @State private var showingHelp = false
    @State private var showingSaveConfirmation = false
    @State private var measurementStep = 0 // 0 = width, 1 = length
    
    var roomName: String
    @ObservedObject var roomStore: RoomStore
    @Binding var isPresented: Bool
    var existingRoom: Room?
    
    init(roomName: String, roomStore: RoomStore, isPresented: Binding<Bool>, existingRoom: Room? = nil) {
        self.roomName = roomName
        self.roomStore = roomStore
        self._isPresented = isPresented
        self.existingRoom = existingRoom
    }
    
    var body: some View {
        ZStack {
            if scanManager.isARSupported && scanManager.isMotionAvailable {
                ARViewContainer(scanManager: scanManager)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Measurement step indicator
                    stepIndicator
                    
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
            
            // Save confirmation
            if showingSaveConfirmation {
                saveConfirmationOverlay
            }
        }
        .onAppear {
            scanManager.setupARSession()
        }
        .onDisappear {
            scanManager.stopSession()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            if scanManager.wallCount > 0 {
                // Show confirmation before discarding measurements
                showingSaveConfirmation = true
            } else {
                isPresented = false
            }
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
        })
    }
    
    var stepIndicator: some View {
        HStack(spacing: 15) {
            Text("Room: \(roomName)")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(15)
                
            Image(systemName: "chevron.right")
                .foregroundColor(.white)
                
            Text(measurementStep == 0 ? "Width" : "Length")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(measurementStep == 0 ? Color.blue.opacity(0.7) : Color.green.opacity(0.7))
                .cornerRadius(15)
        }
        .padding(.top, 20)
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
                .background(measurementStep == 0 ? Color.blue.opacity(0.7) : Color.blue.opacity(0.4))
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
                .background(measurementStep == 1 ? Color.green.opacity(0.7) : Color.green.opacity(0.4))
                .cornerRadius(12)
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(16)
            .padding(.top, 20)
            
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
    
    var saveConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showingSaveConfirmation = false
                }
            
            VStack(spacing: 20) {
                if scanManager.wallCount >= 2 {
                    Text("Save Room Measurements?")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("Width: \(Int(scanManager.roomModel.getRoomWidth() * 100)) cm\nLength: \(Int(scanManager.roomModel.getRoomLength() * 100)) cm")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            // Discard and go back
                            showingSaveConfirmation = false
                            isPresented = false
                        }) {
                            Text("Discard")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 120)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            // Save measurements and go back
                            saveRoom()
                            showingSaveConfirmation = false
                            isPresented = false
                        }) {
                            Text("Save")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 120)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    Text("Incomplete Measurements")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("You need to measure both width and length before saving the room.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            // Continue measuring
                            showingSaveConfirmation = false
                        }) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 120)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            // Discard and go back
                            showingSaveConfirmation = false
                            isPresented = false
                        }) {
                            Text("Discard")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 120)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(30)
            .background(Color.gray.opacity(0.9))
            .cornerRadius(16)
            .padding(30)
        }
    }
    
    var controlBar: some View {
        VStack(spacing: 15) {
            // Main action button
            Button(action: {
                if scanManager.scanMode == .waiting || scanManager.scanMode == .connecting {
                    // Start the measurement process
                    scanManager.beginWallDetection()
                } else if scanManager.scanMode == .scanning {
                    // Complete the measurement
                    scanManager.endWallDetection()
                    
                    // If we just completed a measurement
                    if scanManager.wallCount > 0 {
                        // If this was the first measurement (width), move to the length
                        if measurementStep == 0 && scanManager.wallCount == 1 {
                            measurementStep = 1
                            // Give instruction for next measurement
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                scanManager.sessionInfo = "Now measure the length: tap 'Measure Wall' and walk to opposite wall"
                            }
                        } else if measurementStep == 1 && scanManager.wallCount == 2 {
                            // Both measurements complete - show save prompt
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showingSaveConfirmation = true
                            }
                        }
                    }
                }
            }) {
                Text(actionButtonText)
                    .font(.headline)
                    .frame(width: 180, height: 60)
                    .background(actionButtonColor)
                    .foregroundColor(.white)
                    .cornerRadius(30)
            }
            
            HStack(spacing: 20) {
                // Undo last button
                Button(action: {
                    undoLastMeasurement()
                }) {
                    VStack {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 24))
                        Text("Undo Last")
                            .font(.caption)
                    }
                    .frame(width: 80, height: 60)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                .disabled(scanManager.wallCount == 0)
                .opacity(scanManager.wallCount == 0 ? 0.5 : 1.0)
                
                // Reset button
                Button(action: {
                    resetMeasurements()
                }) {
                    VStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 24))
                        Text("Reset All")
                            .font(.caption)
                    }
                    .frame(width: 80, height: 60)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                
      
            }
        }
        .padding(.bottom, 30)
    }
    
    var actionButtonText: String {
        if measurementStep == 0 && scanManager.wallCount == 0 {
            return "Measure Width"
        } else if measurementStep == 1 && scanManager.wallCount == 1 {
            return "Measure Length"
        } else if scanManager.scanMode == .scanning {
            return "Capture Distance"
        } else if scanManager.scanMode == .completed {
            return "Done"
        } else {
            return "Measure Wall"
        }
    }
    
    var actionButtonColor: Color {
        switch scanManager.scanMode {
        case .waiting, .connecting:
            return measurementStep == 0 ? .blue : .green
        case .scanning:
            return measurementStep == 0 ? .blue : .green
        case .completed:
            return .purple
        }
    }
    
    func undoLastMeasurement() {
        if scanManager.wallCount > 0 {
            scanManager.undoLastWall()
            
            // If we're measuring length and undo, go back to width
            if measurementStep == 1 && scanManager.wallCount == 0 {
                measurementStep = 0
                scanManager.sessionInfo = "Measure the width: tap 'Measure Width' and walk to opposite wall"
            }
        }
    }
    
    func resetMeasurements() {
        scanManager.resetScan()
        measurementStep = 0
    }
    
    func saveRoom() {
        // Convert measurements from meters to centimeters
        let widthInCm = Int(scanManager.roomModel.getRoomWidth() * 100)
        let lengthInCm = Int(scanManager.roomModel.getRoomLength() * 100)
        
        if let existingRoom = existingRoom {
            // Update existing room
            let updatedRoom = Room(
                id: existingRoom.id,
                name: roomName,
                width: Float(widthInCm),
                length: Float(lengthInCm)
            )
            roomStore.updateRoom(updatedRoom)
        } else {
            // Create new room
            let newRoom = Room(
                name: roomName,
                width: Float(widthInCm),
                length: Float(lengthInCm)
            )
            roomStore.addRoom(room: newRoom)
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
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.85)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingHelp = false
                    }
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("How to Measure a Room")
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.top)
                        
                        // Adaptive layout based on device size
                        if geometry.size.width > 700 {
                            // iPad layout - side by side steps
                            HStack(alignment: .top, spacing: 30) {
                                // Step 1: Width
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Step 1: Measure Width")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 4)
                                    
                                    helpStep(number: 1, text: "Press 'Measure Width' button")
                                    helpStep(number: 2, text: "Place your phone against the first wall")
                                    helpStep(number: 3, text: "Walk to the opposite wall")
                                    helpStep(number: 4, text: "Place your phone against the second wall")
                                    helpStep(number: 5, text: "Press 'Capture Distance' to measure")
                                }
                                .frame(minWidth: 0, maxWidth: .infinity)
                                
                                // Step 2: Length
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Step 2: Measure Length")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                        .padding(.vertical, 4)
                                    
                                    helpStep(number: 6, text: "Press 'Measure Length' button")
                                    helpStep(number: 7, text: "Place your phone against the third wall")
                                    helpStep(number: 8, text: "Walk to the opposite wall")
                                    helpStep(number: 9, text: "Place your phone against the fourth wall")
                                    helpStep(number: 10, text: "Press 'Capture Distance' to measure")
                                }
                                .frame(minWidth: 0, maxWidth: .infinity)
                            }
                        } else {
                            // iPhone layout - stacked steps
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Step 1: Measure Width")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 4)
                                
                                helpStep(number: 1, text: "Press 'Measure Width' button")
                                helpStep(number: 2, text: "Place your phone against the first wall")
                                helpStep(number: 3, text: "Walk to the opposite wall")
                                helpStep(number: 4, text: "Place your phone against the second wall")
                                helpStep(number: 5, text: "Press 'Capture Distance' to measure")
                                
                                Text("Step 2: Measure Length")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                
                                helpStep(number: 6, text: "Press 'Measure Length' button")
                                helpStep(number: 7, text: "Place your phone against the third wall")
                                helpStep(number: 8, text: "Walk to the opposite wall")
                                helpStep(number: 9, text: "Place your phone against the fourth wall")
                                helpStep(number: 10, text: "Press 'Capture Distance' to measure")
                            }
                        }
                        
                        Text("Tip: For best results, keep your phone flat against the walls and move in a straight line between measurements. You can use the 'Undo Last' button to retry a measurement.")
                            .font(.footnote)
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)
                            .padding()
                            .fixedSize(horizontal: false, vertical: true)
                        
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
                        .padding(.bottom)
                    }
                    .padding(30)
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(16)
                    .padding(.horizontal, geometry.size.width > 700 ? 60 : 20)
                    .padding(.vertical, 40)
                    .frame(maxWidth: geometry.size.width > 700 ? min(geometry.size.width * 0.85, 1000) : .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
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
