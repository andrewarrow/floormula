import SwiftUI
import CoreMotion
import ARKit
import CoreLocation
import AVFoundation
import Combine

struct ContentView: View {
    // Use the ViewModel for state management
    @StateObject private var viewModel = WallScanViewModel()
    
    var body: some View {
        VStack {
            Text("Walls I Am In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            // Status message
            Text(viewModel.statusMessage)
                .padding(.horizontal)
                .foregroundColor(viewModel.isScanning ? .blue : .primary)
                .fontWeight(viewModel.isScanning ? .bold : .regular)
            
            // Debug information section
            if viewModel.showDebugInfo {
                VStack(alignment: .leading) {
                    Text(viewModel.motionData)
                        .font(.caption)
                    Text(viewModel.locationData)
                        .font(.caption)
                    Text("Wall points: \(viewModel.roomModel.wallPoints.count)")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 5)
            }
            
            // Room visualization
            ZStack {
                // Canvas for drawing the room layout
                Canvas { context, size in
                    if !viewModel.roomModel.wallPoints.isEmpty {
                        // Center point for the canvas
                        let center = CGPoint(x: size.width/2, y: size.height/2)
                        
                        // Draw the room outline
                        var path = Path()
                        let startPoint = CGPoint(
                            x: center.x + viewModel.roomModel.wallPoints[0].position.x * viewModel.canvasScale,
                            y: center.y + viewModel.roomModel.wallPoints[0].position.y * viewModel.canvasScale
                        )
                        path.move(to: startPoint)
                        
                        // Draw lines between points
                        for point in viewModel.roomModel.wallPoints.dropFirst() {
                            let nextPoint = CGPoint(
                                x: center.x + point.position.x * viewModel.canvasScale,
                                y: center.y + point.position.y * viewModel.canvasScale
                            )
                            path.addLine(to: nextPoint)
                        }
                        
                        // Close the path if we've made a full room
                        if viewModel.roomModel.isClosed && viewModel.roomModel.wallPoints.count > 2 {
                            path.closeSubpath()
                            context.fill(path, with: .color(.blue.opacity(0.1)))
                        }
                        
                        // Stroke the path
                        context.stroke(path, with: .color(.blue), lineWidth: 2)
                        
                        // Draw dots at each wall point
                        for point in viewModel.roomModel.wallPoints {
                            let dotPath = Path(ellipseIn: CGRect(
                                x: center.x + point.position.x * viewModel.canvasScale - 4,
                                y: center.y + point.position.y * viewModel.canvasScale - 4,
                                width: 8, height: 8
                            ))
                            context.fill(dotPath, with: .color(.red))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(Color.black.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray, lineWidth: 1)
                )
                
                // Instructional overlay when no points
                if viewModel.roomModel.wallPoints.isEmpty && viewModel.isScanning {
                    Text("Touch your device against walls to map the room")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(8)
                }
            }
            .padding()
            
            // Scale slider
            if !viewModel.roomModel.wallPoints.isEmpty {
                HStack {
                    Text("Scale:")
                    Slider(value: $viewModel.canvasScale, in: 1...20)
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 20) {
                Button(action: { viewModel.toggleScan() }) {
                    Text(viewModel.isScanning ? "Stop Scan" : "Start Scan")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(viewModel.isScanning ? Color.red : Color.blue)
                        .cornerRadius(8)
                }
                
                Button(action: { viewModel.resetScan() }) {
                    Text("Reset")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.gray)
                        .cornerRadius(8)
                }
                
                if !viewModel.roomModel.wallPoints.isEmpty {
                    Button(action: { viewModel.toggleRoomClosure() }) {
                        Text(viewModel.roomModel.isClosed ? "Open Room" : "Close Room")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(viewModel.roomModel.isClosed ? Color.green : Color.orange)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.bottom)
            
            // Debug toggle
            Toggle("Show Debug Info", isOn: $viewModel.showDebugInfo)
                .padding(.horizontal)
                .padding(.bottom)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
