import SwiftUI

struct ManualMeasurementView: View {
    var roomName: String
    @ObservedObject var roomStore: RoomStore
    @Binding var isPresented: Bool
    var existingRoom: Room?
    
    @State private var width: String = ""
    @State private var length: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(roomName: String, roomStore: RoomStore, isPresented: Binding<Bool>, existingRoom: Room? = nil) {
        self.roomName = roomName
        self.roomStore = roomStore
        self._isPresented = isPresented
        self.existingRoom = existingRoom
        
        // Initialize with existing values if editing a room
        if let room = existingRoom {
            self._width = State(initialValue: String(format: "%.0f", room.width))
            self._length = State(initialValue: String(format: "%.0f", room.length))
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(existingRoom == nil ? "Add New Room" : "Edit Room")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Room: \(roomName)")
                .font(.headline)
            
            // Measurement inputs
            VStack(alignment: .leading, spacing: 12) {
                Text("Enter dimensions in centimeters:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Width input
                HStack {
                    Text("Width:")
                        .frame(width: 60, alignment: .leading)
                    
                    TextField("Width in cm", text: $width)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("cm")
                }
                
                // Length input
                HStack {
                    Text("Length:")
                        .frame(width: 60, alignment: .leading)
                    
                    TextField("Length in cm", text: $length)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("cm")
                }
            }
            .padding()
            .background(Color(.textBackgroundColor))
            .cornerRadius(10)
            
            // Preview
            if isValidMeasurements() {
                roomPreview
            }
            
            Spacer()
            
            // Error message if needed
            if showingError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom, 5)
            }
            
            // Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                
                Spacer()
                
                Button(existingRoom == nil ? "Add Room" : "Update Room") {
                    saveRoom()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValidMeasurements())
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 400, height: 400)
    }
    
    private var roomPreview: some View {
        VStack {
            Text("Preview")
                .font(.headline)
                .padding(.bottom, 5)
            
            // Room preview rectangle with proportional dimensions
            GeometryReader { geometry in
                roomPreviewContent(in: geometry)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.textBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
    
    // Helper function to create the room preview content
    private func roomPreviewContent(in geometry: GeometryProxy) -> some View {
        let maxPreviewSize = min(geometry.size.width, geometry.size.height) - 40
        
        // Replace commas with periods for localization support
        let formattedWidth = width.replacingOccurrences(of: ",", with: ".")
        let formattedLength = length.replacingOccurrences(of: ",", with: ".")
        
        let widthValue = Float(formattedWidth) ?? 100
        let lengthValue = Float(formattedLength) ?? 100
        let aspectRatio = widthValue / lengthValue
        
        let previewWidth: CGFloat
        let previewHeight: CGFloat
        
        if aspectRatio > 1 {
            // Wider than tall
            previewWidth = maxPreviewSize
            previewHeight = maxPreviewSize / CGFloat(aspectRatio)
        } else {
            // Taller than wide or square
            previewHeight = maxPreviewSize
            previewWidth = maxPreviewSize * CGFloat(aspectRatio)
        }
        
        return VStack {
            Rectangle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: previewWidth, height: previewHeight)
                .overlay(
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                )
            
            Text(String(format: "%.1f m²", (widthValue * lengthValue) / 10000))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    
    private func isValidMeasurements() -> Bool {
        // Replace commas with periods for localization support
        let formattedWidth = width.replacingOccurrences(of: ",", with: ".")
        let formattedLength = length.replacingOccurrences(of: ",", with: ".")
        
        guard let widthValue = Float(formattedWidth), let lengthValue = Float(formattedLength) else {
            return false
        }
        
        return widthValue > 0 && lengthValue > 0
    }
    
    private func saveRoom() {
        // Validate inputs - replace commas with periods for localization support
        let formattedWidth = width.replacingOccurrences(of: ",", with: ".")
        let formattedLength = length.replacingOccurrences(of: ",", with: ".")
        
        guard let widthValue = Float(formattedWidth), let lengthValue = Float(formattedLength) else {
            showingError = true
            errorMessage = "Please enter valid numeric values."
            return
        }
        
        if widthValue <= 0 || lengthValue <= 0 {
            showingError = true
            errorMessage = "Width and length must be greater than zero."
            return
        }
        
        if let existingRoom = existingRoom {
            // Update existing room
            var updatedRoom = existingRoom
            updatedRoom.width = widthValue
            updatedRoom.length = lengthValue
            roomStore.updateRoom(updatedRoom)
        } else {
            // Create new room
            let newRoom = Room(
                name: roomName,
                width: widthValue,
                length: lengthValue
            )
            roomStore.addRoom(room: newRoom)
        }
        
        isPresented = false
    }
}