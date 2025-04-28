import SwiftUI

struct FloorplanView: View {
    @ObservedObject var roomStore: RoomStore
    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var previousDragValue: CGSize = .zero
    @State private var showingHelp = false
    @State private var snapToGrid = true
    
    // Scaling factor to convert room dimensions from cm to points
    private let baseScaleFactor: CGFloat = 0.4
    
    private var scaleFactor: CGFloat {
        baseScaleFactor * scale
    }
    
    // Canvas size for scrolling
    private let canvasWidth: CGFloat = 3000
    private let canvasHeight: CGFloat = 3000
    
    // Grid size for snapping
    private let gridSize: CGFloat = 50
    
    var body: some View {
        ZStack {
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    // Background grid
                    GridBackground(gridSize: gridSize, showGrid: true)
                        .frame(width: canvasWidth, height: canvasHeight)
                    
                    // Room boxes
                    ForEach(roomStore.rooms) { room in
                        DraggableRoomBox(
                            room: room,
                            scaleFactor: scaleFactor,
                            position: room.position?.point ?? CGPoint(x: CGFloat(room.id.hashValue % 800) + 200, 
                                                       y: CGFloat(room.id.hashValue % 600) + 200),
                            onPositionChanged: { newPosition in
                                let snappedPosition = snapToGrid ? snapPositionToGrid(newPosition) : newPosition
                                updateRoomPosition(room: room, newPosition: snappedPosition)
                            }
                        )
                    }
                }
                .frame(width: canvasWidth, height: canvasHeight)
                .scaleEffect(scale)
            }
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = min(max(0.5, scale * value), 2.0)
                        scale = newScale
                    }
            )
            
            // Controls panel
            VStack {
                Spacer()
                
                HStack {
                    // Help/Info button
                    Button(action: {
                        showingHelp = true
                    }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .padding(.leading)
                    
                    // Snap to grid toggle
                    Toggle(isOn: $snapToGrid) {
                        Text("Snap to Grid")
                            .font(.caption)
                    }
                    .frame(width: 120)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Zoom controls
                    HStack(spacing: 12) {
                        Button(action: {
                            scale = max(scale - 0.1, 0.5)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        
                        Text(String(format: "%.1fx", scale))
                            .font(.caption)
                            .frame(width: 40)
                        
                        Button(action: {
                            scale = min(scale + 0.1, 2.0)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.trailing)
                }
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.9))
                .cornerRadius(8)
                .shadow(radius: 2)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .alert(isPresented: $showingHelp) {
                Alert(
                    title: Text("Floorplan Help"),
                    message: Text("• Drag rooms to position them on the floorplan\n• Use pinch gesture or +/- buttons to zoom\n• Toggle 'Snap to Grid' for precise positioning\n• Tap and hold to see room details"),
                    dismissButton: .default(Text("Got it!"))
                )
            }
        }
        .navigationTitle("Floorplan")
        .background(Color(.systemGray6))
    }
    
    private func snapPositionToGrid(_ position: CGPoint) -> CGPoint {
        let snappedX = round(position.x / gridSize) * gridSize
        let snappedY = round(position.y / gridSize) * gridSize
        return CGPoint(x: snappedX, y: snappedY)
    }
    
    private func updateRoomPosition(room: Room, newPosition: CGPoint) {
        // Find the room in the store
        if let index = roomStore.rooms.firstIndex(where: { $0.id == room.id }) {
            // Create updated room
            var updatedRoom = room
            updatedRoom.position = RoomPosition(point: newPosition)
            
            // Update in store
            roomStore.updateRoom(updatedRoom)
        }
    }
}

struct DraggableRoomBox: View {
    let room: Room
    let scaleFactor: CGFloat
    @State var position: CGPoint
    let onPositionChanged: (CGPoint) -> Void
    @State private var isDragging = false
    
    var body: some View {
        RoomBox(room: room, scaleFactor: scaleFactor, isSelected: isDragging)
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        position = CGPoint(
                            x: position.x + value.translation.width / scaleFactor,
                            y: position.y + value.translation.height / scaleFactor
                        )
                        onPositionChanged(position)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

struct RoomBox: View {
    let room: Room
    let scaleFactor: CGFloat
    var isSelected: Bool = false
    @State private var showDetails = false
    
    var width: CGFloat {
        max(CGFloat(room.width) * scaleFactor, 40)
    }
    
    var height: CGFloat {
        max(CGFloat(room.length) * scaleFactor, 40)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room name header
            Text(room.name)
                .font(.caption.bold())
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.green : Color.blue)
                .foregroundColor(.white)
            
            // Room rectangle
            ZStack {
                Rectangle()
                    .stroke(isSelected ? Color.green : Color.blue, lineWidth: isSelected ? 3 : 2)
                    .background((isSelected ? Color.green : Color.blue).opacity(0.1))
                    .frame(width: width, height: height)
                
                // Room dimensions and name in the center
                VStack {
                    Text(room.name)
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                        .opacity(width > 100 ? 1 : 0)
                        .padding(.bottom, 2)
                    
                    Text("\(Int(room.width))×\(Int(room.length))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", room.area)) m²")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(width > 80 ? 1 : 0)
                }
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Info button in the corner
                if width > 60 && height > 60 {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                showDetails.toggle()
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .padding(4)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .frame(width: width, height: height + 24)
        .shadow(radius: isSelected ? 4 : 2)
        .popover(isPresented: $showDetails) {
            RoomDetailPopover(room: room)
        }
    }
}

struct RoomDetailPopover: View {
    let room: Room
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(room.name)
                .font(.headline)
                .padding(.bottom, 5)
            
            HStack {
                Text("Width:")
                    .foregroundColor(.secondary)
                Text("\(Int(room.width)) cm")
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Length:")
                    .foregroundColor(.secondary)
                Text("\(Int(room.length)) cm")
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Area:")
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f m²", room.area))
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Created:")
                    .foregroundColor(.secondary)
                Text(room.createdAt, style: .date)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .frame(width: 250)
    }
}

struct GridBackground: View {
    let gridSize: CGFloat
    let showGrid: Bool
    
    var body: some View {
        Canvas { context, size in
            if showGrid {
                // Draw vertical lines
                for x in stride(from: 0, to: size.width, by: gridSize) {
                    let isMainLine = Int(x) % Int(gridSize * 5) == 0
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    context.stroke(
                        path,
                        with: .color(isMainLine ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15)),
                        lineWidth: isMainLine ? 1 : 0.5
                    )
                }
                
                // Draw horizontal lines
                for y in stride(from: 0, to: size.height, by: gridSize) {
                    let isMainLine = Int(y) % Int(gridSize * 5) == 0
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(
                        path,
                        with: .color(isMainLine ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15)),
                        lineWidth: isMainLine ? 1 : 0.5
                    )
                }
                
                // Draw measurement indicators on main grid lines
                let fontSize: CGFloat = 10
                for x in stride(from: 0, to: size.width, by: gridSize * 5) {
                    let meters = Int(x / gridSize)
                    if meters > 0 {
                        let text = Text("\(meters)m").font(.system(size: fontSize))
                        context.draw(text, at: CGPoint(x: x + 2, y: 2))
                    }
                }
                
                for y in stride(from: 0, to: size.height, by: gridSize * 5) {
                    let meters = Int(y / gridSize) 
                    if meters > 0 {
                        let text = Text("\(meters)m").font(.system(size: fontSize))
                        context.draw(text, at: CGPoint(x: 2, y: y + 2))
                    }
                }
            } else {
                // Draw a simple background without grid
                let path = Path(CGRect(origin: .zero, size: size))
                context.fill(path, with: .color(Color(.systemGray6)))
            }
        }
    }
}