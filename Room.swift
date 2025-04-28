import Foundation
import SwiftUI

struct Room: Identifiable, Codable {
    let id: UUID
    var name: String
    var width: Float  // in centimeters
    var length: Float // in centimeters
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, width: Float = 0, length: Float = 0) {
        self.id = id
        self.name = name
        self.width = width
        self.length = length
        self.createdAt = Date()
    }
    
    var area: Float {
        return width * length / 10000 // convert to square meters
    }
}

class RoomStore: ObservableObject {
    @Published var rooms: [Room] = []
    
    private let savePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("rooms.json")
    
    init() {
        loadRooms()
    }
    
    func saveRooms() {
        do {
            let data = try JSONEncoder().encode(rooms)
            try data.write(to: savePath, options: [.atomic])
        } catch {
            print("Error saving rooms: \(error)")
        }
    }
    
    func loadRooms() {
        do {
            if let data = try? Data(contentsOf: savePath) {
                rooms = try JSONDecoder().decode([Room].self, from: data)
            }
        } catch {
            print("Error loading rooms: \(error)")
            rooms = []
        }
    }
    
    func addRoom(room: Room) {
        rooms.append(room)
        saveRooms()
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