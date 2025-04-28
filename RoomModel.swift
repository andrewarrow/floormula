import Foundation
import ARKit
import simd

struct Wall: Identifiable {
    let id = UUID()
    let startPoint: simd_float3
    let endPoint: simd_float3
    let normalVector: simd_float3
    let timestamp: Date
    
    var length: Float {
        return simd_distance(startPoint, endPoint)
    }
    
    // 2D projection for floor plan calculations (assumes walls are vertical)
    var start2D: SIMD2<Float> {
        return SIMD2<Float>(startPoint.x, startPoint.z)
    }
    
    var end2D: SIMD2<Float> {
        return SIMD2<Float>(endPoint.x, endPoint.z)
    }
    
    // Line direction vector in 2D
    var direction2D: SIMD2<Float> {
        return simd_normalize(end2D - start2D)
    }
}

class RoomModel: ObservableObject {
    @Published var walls: [Wall] = []
    @Published var currentRoom: [Wall] = []
    @Published var roomArea: Float = 0.0
    @Published var isComplete: Bool = false
    
    // Configuration options
    private let wallConnectionThreshold: Float = 0.3  // 30cm
    private let roomClosureThreshold: Float = 0.5     // 50cm
    private let minWallsForRoom: Int = 3
    
    func addWall(startPoint: simd_float3, endPoint: simd_float3, normalVector: simd_float3) {
        let wall = Wall(startPoint: startPoint, endPoint: endPoint, normalVector: normalVector, timestamp: Date())
        currentRoom.append(wall)
        walls.append(wall)
        
        checkRoomClosure()
        calculateRoomArea()
    }
    
    func clear() {
        currentRoom.removeAll()
        roomArea = 0.0
        isComplete = false
    }
    
    // Calculate room area using Shoelace formula (Gauss's area formula)
    private func calculateRoomArea() {
        guard currentRoom.count >= 3 else {
            roomArea = 0.0
            return
        }
        
        // Extract 2D points (assuming room is mostly on xz plane for simplicity)
        var points: [SIMD2<Float>] = []
        
        // Use wall endpoints as vertices
        for wall in currentRoom {
            if points.isEmpty {
                points.append(wall.start2D)
            }
            points.append(wall.end2D)
        }
        
        // Calculate area using Shoelace formula
        var area: Float = 0.0
        let n = points.count
        
        for i in 0..<n {
            let j = (i + 1) % n
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }
        
        roomArea = abs(area) / 2.0
    }
    
    // Check if the room is closed (first and last walls connect)
    private func checkRoomClosure() {
        guard currentRoom.count >= minWallsForRoom else {
            isComplete = false
            return
        }
        
        let firstWallStart = currentRoom.first!.startPoint
        let lastWallEnd = currentRoom.last!.endPoint
        
        // Check if the start of the first wall is close to the end of the last wall
        let distance = simd_distance(firstWallStart, lastWallEnd)
        isComplete = distance < roomClosureThreshold
    }
    
    // Advanced method to check if room is closed with better error tolerance
    func isRoomClosed() -> Bool {
        guard currentRoom.count >= minWallsForRoom else { return false }
        
        // Basic check: is last wall's endpoint close to first wall's start point?
        let firstWallStart = currentRoom.first!.startPoint
        let lastWallEnd = currentRoom.last!.endPoint
        let directDistance = simd_distance(firstWallStart, lastWallEnd)
        
        if directDistance < wallConnectionThreshold {
            return true
        }
        
        // If we have enough walls and they form a roughly polygonal shape
        if currentRoom.count >= 4 {
            // Check if the walls form a path that approximately returns to the starting point
            let startPosition = currentRoom.first!.startPoint
            let currentPosition = currentRoom.last!.endPoint
            let totalPathLength = currentRoom.reduce(0) { $0 + $1.length }
            
            // If we've moved a significant distance but end up close to where we started
            if totalPathLength > 4.0 && directDistance < roomClosureThreshold {
                return true
            }
        }
        
        return false
    }
    
    // Helper to get average room height
    func getAverageRoomHeight() -> Float {
        guard !currentRoom.isEmpty else { return 0 }
        
        // Average Y coordinate of all wall endpoints
        let totalHeight = currentRoom.reduce(0.0) { $0 + $1.startPoint.y + $1.endPoint.y }
        return totalHeight / Float(currentRoom.count * 2)
    }
    
    // Get a formatted description of the room dimensions
    func getRoomDimensions() -> String {
        guard currentRoom.count >= 3 else {
            return "Not enough walls to calculate dimensions"
        }
        
        // Find extreme coordinates to get rough width and length
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minZ: Float = .infinity
        var maxZ: Float = -.infinity
        
        for wall in currentRoom {
            minX = min(minX, wall.startPoint.x, wall.endPoint.x)
            maxX = max(maxX, wall.startPoint.x, wall.endPoint.x)
            minZ = min(minZ, wall.startPoint.z, wall.endPoint.z)
            maxZ = max(maxZ, wall.startPoint.z, wall.endPoint.z)
        }
        
        let width = maxX - minX
        let length = maxZ - minZ
        let height = getAverageRoomHeight()
        
        return String(format: "Approx. %.1f x %.1f x %.1f meters", width, length, height)
    }
}