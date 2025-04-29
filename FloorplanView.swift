import SwiftUI

struct FloorplanView: View {
    @ObservedObject var roomStore: RoomStore
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var previousOffset: CGPoint = .zero
    @State private var selectedRoom: Room? = nil
    @State private var roomPositionsInitialized: Bool = false
    
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
                        .onTapGesture {
                            selectedRoom = nil
                        }
                }
            }
            .onAppear {
                if !roomPositionsInitialized {
                    initializeRoomPositions()
                    roomPositionsInitialized = true
                }
            }
            
            // Info panel removed
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
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 150)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
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
        
        // Use the same scale factor as before, but with full screen dimensions
        let availableWidth = UIScreen.main.bounds.width - padding
        let availableHeight = UIScreen.main.bounds.height - 150 - padding
        let widthScale = availableWidth / CGFloat(maxRoomDimension)
        let heightScale = availableHeight / CGFloat(maxRoomDimension)
        
        // Use the smaller of the two scales to ensure rooms fit within the screen
        return min(widthScale, heightScale) * 0.8
    }
    
    private func calculateLayoutWidth() -> CGFloat {
        return UIScreen.main.bounds.width
    }
    
    private func calculateLayoutHeight() -> CGFloat {
        return UIScreen.main.bounds.height - 150
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
        
        // Shift layout to the left side of the screen
        let layoutWidth = calculateLayoutWidth()
        let layoutHeight = calculateLayoutHeight()
        
        // Define a grid with more columns than rows to lay out rooms along the left side
        let columns = min(3, sortedRooms.count)
        let rows = ceil(Double(sortedRooms.count) / Double(columns))
        
        let cellWidth = layoutWidth / CGFloat(columns + 1) // +1 for padding on the right
        let cellHeight = layoutHeight / CGFloat(rows)
        
        // Starting position offset (shift everything to the left)
        let xOffset = cellWidth * 0.5
        
        for (index, room) in sortedRooms.enumerated() {
            let roomWidth = max(CGFloat(room.width) * scaleFactor, minRoomSize)
            let roomHeight = max(CGFloat(room.length) * scaleFactor, minRoomSize)
            
            // Calculate row and column for this room
            let row = index / columns
            let col = index % columns
            
            // Calculate position, keeping rooms on the left side
            let x = xOffset + (cellWidth * CGFloat(col))
            let y = (cellHeight * (CGFloat(row) + 0.5))
            
            var position = CGPoint(x: x, y: y)
            
            // If the room already has a stored position, use that instead
            if let existingPosition = room.position {
                position = CGPoint(x: CGFloat(existingPosition.x), y: CGFloat(existingPosition.y))
            }
            
            result.append(RoomWithPosition(room: room, position: position))
            
            let rect = CGRect(
                x: position.x - roomWidth/2,
                y: position.y - roomHeight/2,
                width: roomWidth,
                height: roomHeight
            )
            occupiedAreas.append((rect, room))
        }
        
        return result
    }
}

extension CGRect {
    var area: Double {
        return Double(width * height)
    }
}

// MARK: - Room Position Management
extension FloorplanView {
    private func initializeRoomPositions() {
        let roomsWithoutPositions = roomStore.rooms.filter { $0.position == nil }
        if roomsWithoutPositions.isEmpty {
            return
        }
        
        let layoutWidth = calculateLayoutWidth()
        let layoutHeight = calculateLayoutHeight()
        
        // Define a grid with more columns than rows to lay out rooms along the left side
        let columns = min(3, roomStore.rooms.count)
        let rows = ceil(Double(roomStore.rooms.count) / Double(columns))
        
        let cellWidth = layoutWidth / CGFloat(columns + 1) // +1 for padding on the right
        let cellHeight = layoutHeight / CGFloat(rows)
        
        // Starting position offset (shift everything to the left)
        let xOffset = cellWidth * 0.5
        
        var updates: [(Room, RoomPosition)] = []
        
        for (index, room) in roomStore.rooms.enumerated() {
            // Skip rooms that already have positions
            if room.position != nil {
                continue
            }
            
            // Calculate row and column for this room
            let row = index / columns
            let col = index % columns
            
            // Calculate position, keeping rooms on the left side
            let x = xOffset + (cellWidth * CGFloat(col))
            let y = (cellHeight * (CGFloat(row) + 0.5))
            
            let newPosition = RoomPosition(x: Double(x), y: Double(y))
            updates.append((room, newPosition))
        }
        
        // Apply all position updates at once outside of the view update cycle
        DispatchQueue.main.async {
            for (room, position) in updates {
                var updatedRoom = room
                updatedRoom.position = position
                self.roomStore.updateRoom(updatedRoom)
            }
        }
    }
}
