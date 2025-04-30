import Foundation
import SwiftUI

struct Room: Identifiable, Codable {
    let id: UUID
    var name: String
    var width: Float  // in centimeters
    var length: Float // in centimeters
    var createdAt: Date
    var position: RoomPosition?
    var rotation: Int = 0 // 0, 90, 180, 270 degrees
    
    init(id: UUID = UUID(), name: String, width: Float = 0, length: Float = 0, position: RoomPosition? = nil, rotation: Int = 0) {
        self.id = id
        self.name = name
        self.width = width
        self.length = length
        self.createdAt = Date()
        self.position = position
        self.rotation = rotation
    }
    
    var area: Float {
        return width * length / 10000 // convert to square meters
    }
    
    // Custom coding keys to support backward compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, width, length, createdAt, position, rotation
    }
    
    // Custom decoder to handle missing rotation field in older saved data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        width = try container.decode(Float.self, forKey: .width)
        length = try container.decode(Float.self, forKey: .length)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        position = try container.decodeIfPresent(RoomPosition.self, forKey: .position)
        // Use default value of 0 if rotation is not present in the JSON
        rotation = try container.decodeIfPresent(Int.self, forKey: .rotation) ?? 0
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
    
    func importRoomsFromJSON(_ jsonData: Data) -> Bool {
        do {
            let importedRooms = try JSONDecoder().decode([Room].self, from: jsonData)
            
            // Add only rooms that don't already exist
            var newRoomsAdded = false
            for importedRoom in importedRooms {
                if !rooms.contains(where: { $0.id == importedRoom.id }) {
                    rooms.append(importedRoom)
                    newRoomsAdded = true
                }
            }
            
            if newRoomsAdded {
                saveRooms()
            }
            
            return true
        } catch {
            print("Error importing rooms: \(error)")
            return false
        }
    }
}

