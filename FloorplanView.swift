import SwiftUI

struct FloorplanView: View {
    @ObservedObject var roomStore: RoomStore
    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var previousDragValue: CGSize = .zero
    @State private var showingHelp = false
    @State private var snapToGrid = true
    @State private var showMinimap = true
    
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
    
    // Scrollview reader to track scrolling position
    @State private var scrollPosition = CGPoint(x: 1500, y: 1500) // Default to center of 3000x3000 canvas
    
    var body: some View {
        ZStack {
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    // Background grid
                    GridBackground(gridSize: gridSize, showGrid: true)
                        .frame(width: canvasWidth, height: canvasHeight)
                    
                    // Room counter
                    Text("\(roomStore.rooms.count) room(s)")
                        .font(.caption)
                        .padding(6)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                        .position(x: 100, y: 50)
                    
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
                .onChange(of: roomStore.rooms.count) { _ in
                    // If a new room is added, reset view to see all rooms
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewAllRooms()
                    }
                }
            }
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        // Dampen the sensitivity by applying only a fraction of the change
                        // and using the initial scale as a reference
                        let dampingFactor: CGFloat = 0.5 // Lower value = less sensitive
                        let scaleDelta = (value - 1.0) * dampingFactor
                        let newScale = min(max(0.2, scale * (1.0 + scaleDelta)), 3.0)
                        scale = newScale
                    }
            )
            
            // Minimap overlay
            if showMinimap && roomStore.rooms.count > 1 {
                MinimapView(
                    rooms: roomStore.rooms,
                    canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
                    viewPosition: scrollPosition,
                    viewScale: scale
                )
                .frame(width: 150, height: 150)
                .background(Color.white.opacity(0.8))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .shadow(radius: 3)
                .position(x: UIScreen.main.bounds.width - 85, y: 100)
            }
            
            // Controls panel
            VStack {
                // Top control buttons
                HStack {
                    Spacer()
                    
                    Button(action: { 
                        showMinimap.toggle()
                    }) {
                        Image(systemName: showMinimap ? "map.fill" : "map")
                            .padding(8)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                    
                    Button(action: { 
                        viewAllRooms()
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .padding(8)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                }
                .padding(.trailing)
                .padding(.top, 8)
                
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
                            // Zoom out by 10% of current scale for smoother transition
                            let zoomFactor: CGFloat = 0.9 // 10% reduction
                            scale = max(scale * zoomFactor, 0.2)
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
                            // Zoom in by 10% of current scale for smoother transition
                            let zoomFactor: CGFloat = 1.1 // 10% increase
                            scale = min(scale * zoomFactor, 3.0)
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
                    message: Text("• Drag rooms to position them on the floorplan\n• Use pinch gesture or +/- buttons to zoom\n• Tap 'View All' button to see all rooms\n• Use minimap to see your current position\n• Toggle 'Snap to Grid' for precise positioning\n• Tap and hold a room to see details"),
                    dismissButton: .default(Text("Got it!"))
                )
            }
        }
        .navigationTitle("Floorplan")
        .background(Color(.systemGray6))
        .onAppear {
            // Auto-view all rooms when the floorplan is opened
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewAllRooms()
            }
        }
    }
    
    // Function to view all rooms
    private func viewAllRooms() {
        guard !roomStore.rooms.isEmpty else { return }
        
        // Find bounds of all rooms
        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var minY: CGFloat = .infinity
        var maxY: CGFloat = -.infinity
        
        for room in roomStore.rooms {
            let position = room.position?.point ?? CGPoint(
                x: CGFloat(room.id.hashValue % 800) + 200,
                y: CGFloat(room.id.hashValue % 600) + 200
            )
            
            // Room dimensions in points
            let width = max(CGFloat(room.width) * scaleFactor, 40)
            let height = max(CGFloat(room.length) * scaleFactor, 40)
            
            // Update bounds
            minX = min(minX, position.x - width/2)
            maxX = max(maxX, position.x + width/2)
            minY = min(minY, position.y - height/2)
            maxY = max(maxY, position.y + height/2)
        }
        
        // Add padding
        let padding: CGFloat = 100
        minX -= padding
        maxX += padding
        minY -= padding
        maxY += padding
        
        // Calculate required scale
        let contentWidth = maxX - minX
        let contentHeight = maxY - minY
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height - 200 // Account for nav bars and controls
        
        let horizontalScale = screenWidth / contentWidth
        let verticalScale = screenHeight / contentHeight
        
        // Use the smaller scale to ensure everything fits
        var newScale = min(horizontalScale, verticalScale)
        
        // Apply scale limits
        newScale = min(max(newScale, 0.2), 3.0)
        scale = newScale
        
        // Calculate center of all rooms
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        
        // Update scroll position to center view on all rooms
        scrollPosition = CGPoint(x: centerX, y: centerY)
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

// Minimap view to help with navigation
struct MinimapView: View {
    let rooms: [Room]
    let canvasSize: CGSize
    let viewPosition: CGPoint
    let viewScale: CGFloat
    
    // Scale factor for minimap
    private let minimapScale: CGFloat = 0.05
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6)
                .opacity(0.7)
            
            // Room representations
            ForEach(rooms) { room in
                let position = room.position?.point ?? CGPoint(
                    x: CGFloat(room.id.hashValue % 800) + 200,
                    y: CGFloat(room.id.hashValue % 600) + 200
                )
                
                // Scale position to minimap
                let scaledPosition = CGPoint(
                    x: position.x * minimapScale,
                    y: position.y * minimapScale
                )
                
                Rectangle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .position(scaledPosition)
            }
            
            // Current viewport representation
            let viewportWidth = UIScreen.main.bounds.width / viewScale
            let viewportHeight = UIScreen.main.bounds.height / viewScale
            
            Rectangle()
                .stroke(Color.red, lineWidth: 2)
                .frame(
                    width: viewportWidth * minimapScale,
                    height: viewportHeight * minimapScale
                )
                .position(x: viewPosition.x * minimapScale, y: viewPosition.y * minimapScale)
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