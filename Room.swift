import Foundation
import SwiftUI

struct Room: Identifiable, Codable {
    let id: UUID
    var name: String
    var width: Float  // in centimeters
    var length: Float // in centimeters
    var createdAt: Date
    var position: RoomPosition?
    
    init(id: UUID = UUID(), name: String, width: Float = 0, length: Float = 0, position: RoomPosition? = nil) {
        self.id = id
        self.name = name
        self.width = width
        self.length = length
        self.createdAt = Date()
        self.position = position
    }
    
    var area: Float {
        return width * length / 10000 // convert to square meters
    }
}

struct RoomPosition: Codable, Equatable {
    var x: Double
    var y: Double
    
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    init(point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
    
    var point: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

class RoomStore: ObservableObject {
    @Published var rooms: [Room] = []
    
    private let savePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("rooms.json")
    
    init() {
        loadRooms()
        validateRooms()
    }
    
    func saveRooms() {
        do {
            let data = try JSONEncoder().encode(rooms)
            try data.write(to: savePath, options: [.atomic])
            print("Saved \(rooms.count) rooms successfully")
        } catch {
            print("Error saving rooms: \(error)")
        }
    }
    
    func loadRooms() {
        do {
            if let data = try? Data(contentsOf: savePath) {
                rooms = try JSONDecoder().decode([Room].self, from: data)
                print("Loaded \(rooms.count) rooms successfully")
            }
        } catch {
            print("Error loading rooms: \(error)")
            rooms = []
        }
    }
    
    // Validate rooms to ensure all are correctly configured
    func validateRooms() {
        // Filter out any rooms with invalid positions
        let validRooms = rooms.filter { room in
            if let position = room.position {
                return !position.x.isNaN && !position.y.isNaN
            }
            return true
        }
        
        if validRooms.count != rooms.count {
            print("Removed \(rooms.count - validRooms.count) invalid rooms")
            rooms = validRooms
            saveRooms()
        }
        
        // Ensure all rooms have positions
        for (index, room) in rooms.enumerated() where room.position == nil {
            // Assign a default position using hash as a deterministic starting point
            var updatedRoom = room
            updatedRoom.position = RoomPosition(
                x: Double(room.id.hashValue % 800) + 200,
                y: Double(room.id.hashValue % 600) + 200
            )
            rooms[index] = updatedRoom
            print("Assigned default position to room: \(room.name)")
        }
        
        // Save any changes made during validation
        saveRooms()
    }
    
    func addRoom(room: Room) {
        // Create a room with position if it doesn't have one
        var newRoom = room
        if newRoom.position == nil {
            newRoom.position = RoomPosition(
                x: Double(room.id.hashValue % 800) + 200,
                y: Double(room.id.hashValue % 600) + 200
            )
        }
        
        DispatchQueue.main.async {
            self.rooms.append(newRoom)
            self.saveRooms()
            print("Added new room: \(newRoom.name), total: \(self.rooms.count)")
        }
    }
    
    func deleteRoom(at indexSet: IndexSet) {
        rooms.remove(atOffsets: indexSet)
        saveRooms()
    }
    
    func updateRoom(_ room: Room) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index] = room
            saveRooms()
        }
    }
}