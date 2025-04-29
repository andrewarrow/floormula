import SwiftUI

struct FloorplanView: View {
    @ObservedObject var roomStore: RoomStore
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var previousOffset: CGPoint = .zero
    @State private var selectedRoom: Room? = nil
    
    private let padding: CGFloat = 20
    private let minRoomSize: CGFloat = 50
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack {
                if roomStore.rooms.isEmpty {
                    emptyState
                } else {
                    roomLayout
                        .scaleEffect(scale)
                        .offset(x: offset.x + dragOffset.width, y: offset.y + dragOffset.height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    offset = CGPoint(
                                        x: offset.x + dragOffset.width,
                                        y: offset.y + dragOffset.height
                                    )
                                    dragOffset = .zero
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = value / scale
                                    if scale * newScale >= 0.5 && scale * newScale <= 3.0 {
                                        scale = scale * newScale
                                    }
                                }
                        )
                        .onTapGesture {
                            selectedRoom = nil
                        }
                }
            }
            
            VStack {
                Spacer()
                
                HStack {
                    Button(action: {
                        if scale > 0.5 {
                            scale -= 0.1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        offset = .zero
                        scale = 1.0
                    }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        if scale < 3.0 {
                            scale += 0.1
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(20)
                .padding()
            }
            
            if let room = selectedRoom {
                VStack(alignment: .leading) {
                    Text(room.name)
                        .font(.headline)
                    Text("\(Int(room.width)) × \(Int(room.length)) cm")
                        .font(.subheadline)
                    Text(String(format: "%.1f m²", room.area))
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)
                .position(x: UIScreen.main.bounds.width / 2, y: 100)
                .transition(.opacity)
                .animation(.easeInOut, value: selectedRoom != nil)
            }
        }
        .navigationTitle("Floorplan")
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Rooms Added")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Add rooms in the Rooms tab to visualize your floorplan")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var roomLayout: some View {
        ZStack {
            roomBoxes
        }
        .frame(width: calculateLayoutWidth(), height: calculateLayoutHeight())
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(20)
    }
    
    private var roomBoxes: some View {
        ZStack {
            ForEach(calculateRoomPositions()) { roomWithPosition in
                roomBox(room: roomWithPosition.room, position: roomWithPosition.position)
            }
        }
    }
    
    private func roomBox(room: Room, position: CGPoint) -> some View {
        let width = CGFloat(room.width) * scaleFactor
        let length = CGFloat(room.length) * scaleFactor
        
        return Rectangle()
            .fill(selectedRoom?.id == room.id ? Color.blue.opacity(0.3) : Color.blue.opacity(0.1))
            .frame(width: max(width, minRoomSize), height: max(length, minRoomSize))
            .overlay(
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
            )
            .overlay(
                Text(room.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: max(width, minRoomSize) - 10)
            )
            .position(position)
            .onTapGesture {
                selectedRoom = room
            }
    }
    
    private var scaleFactor: CGFloat {
        // Calculate a scale factor to fit rooms in the view
        let maxRoomDimension = roomStore.rooms.reduce(0) { max($0, CGFloat(max($1.width, $1.length))) }
        if maxRoomDimension <= 0 {
            return 1.0
        }
        
        let availableWidth = UIScreen.main.bounds.width - (padding * 2)
        return availableWidth / (CGFloat(maxRoomDimension) * 1.5)
    }
    
    private func calculateLayoutWidth() -> CGFloat {
        let maxX = roomStore.rooms.reduce(0) { max($0, CGFloat($1.width)) }
        return max(CGFloat(maxX) * scaleFactor, UIScreen.main.bounds.width - 40) + padding * 2
    }
    
    private func calculateLayoutHeight() -> CGFloat {
        let maxY = roomStore.rooms.reduce(0) { max($0, CGFloat($1.length)) }
        return max(CGFloat(maxY) * scaleFactor, UIScreen.main.bounds.width - 40) + padding * 2
    }
    
    // Struct to hold room and its position for layout purposes
    struct RoomWithPosition: Identifiable {
        let id = UUID()
        let room: Room
        let position: CGPoint
    }
    
    private func calculateRoomPositions() -> [RoomWithPosition] {
        let sortedRooms = roomStore.rooms.sorted { $0.area > $1.area }
        var result: [RoomWithPosition] = []
        var occupiedAreas: [(CGRect, Room)] = []
        
        // Layout algorithm: Place rooms in a grid, attempting to avoid overlaps
        let gridSize = ceil(sqrt(Double(sortedRooms.count)))
        let layoutWidth = calculateLayoutWidth()
        let layoutHeight = calculateLayoutHeight()
        
        for room in sortedRooms {
            let roomWidth = max(CGFloat(room.width) * scaleFactor, minRoomSize)
            let roomHeight = max(CGFloat(room.length) * scaleFactor, minRoomSize)
            
            // If the room already has a position, use it
            if let position = room.position {
                let point = CGPoint(x: CGFloat(position.x), y: CGFloat(position.y))
                result.append(RoomWithPosition(room: room, position: point))
                let rect = CGRect(
                    x: point.x - roomWidth/2,
                    y: point.y - roomHeight/2,
                    width: roomWidth,
                    height: roomHeight
                )
                occupiedAreas.append((rect, room))
                continue
            }
            
            // Find a position where this room doesn't overlap with others
            var bestPosition: CGPoint?
            var minOverlap = Double.infinity
            
            // Try positions in a grid pattern
            for row in 0..<Int(gridSize) {
                for col in 0..<Int(gridSize) {
                    let cellWidth = layoutWidth / CGFloat(gridSize)
                    let cellHeight = layoutHeight / CGFloat(gridSize)
                    
                    let x = cellWidth * (CGFloat(col) + 0.5)
                    let y = cellHeight * (CGFloat(row) + 0.5)
                    
                    let proposedRect = CGRect(
                        x: x - roomWidth/2,
                        y: y - roomHeight/2,
                        width: roomWidth,
                        height: roomHeight
                    )
                    
                    // Calculate total overlap with existing rooms
                    let totalOverlap = occupiedAreas.reduce(0.0) { sum, occupied in
                        let overlap = proposedRect.intersection(occupied.0).area
                        return sum + overlap
                    }
                    
                    if totalOverlap < minOverlap {
                        minOverlap = totalOverlap
                        bestPosition = CGPoint(x: x, y: y)
                    }
                }
            }
            
            if let position = bestPosition {
                result.append(RoomWithPosition(room: room, position: position))
                
                // Update room position in the store
                var updatedRoom = room
                updatedRoom.position = RoomPosition(x: Double(position.x), y: Double(position.y))
                roomStore.updateRoom(updatedRoom)
                
                let rect = CGRect(
                    x: position.x - roomWidth/2,
                    y: position.y - roomHeight/2,
                    width: roomWidth,
                    height: roomHeight
                )
                occupiedAreas.append((rect, room))
            }
        }
        
        return result
    }
}

extension CGRect {
    var area: Double {
        return Double(width * height)
    }
}
