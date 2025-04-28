import Foundation
import ARKit
import simd

struct Wall: Identifiable {
    let id = UUID()
    let startPoint: simd_float3
    let endPoint: simd_float3
    let length: Float
    
    init(startPoint: simd_float3, endPoint: simd_float3, normalVector: simd_float3 = simd_float3(0, 0, 0)) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.length = simd_distance(startPoint, endPoint)
    }
}

class RoomModel: ObservableObject {
    @Published var walls: [Wall] = []
    @Published var width: Float = 0.0
    @Published var length: Float = 0.0
    
    // Add a wall measurement
    func addWall(startPoint: simd_float3, endPoint: simd_float3, normalVector: simd_float3) {
        let wall = Wall(startPoint: startPoint, endPoint: endPoint)
        walls.append(wall)
        
        // Update dimensions after adding a wall
        updateRoomDimensions()
    }
    
    // Clear all walls
    func clear() {
        walls.removeAll()
        width = 0.0
        length = 0.0
    }
    
    // Update room dimensions based on wall measurements
    private func updateRoomDimensions() {
        // If we have at least one wall, use its length as width
        if let firstWall = walls.first {
            width = firstWall.length
        }
        
        // If we have at least two walls, use the second wall's length as length
        if walls.count >= 2 {
            length = walls[1].length
        }
        
        // If we have more than two walls, use the longest as width and second longest as length
        if walls.count > 2 {
            let sortedWalls = walls.sorted { $0.length > $1.length }
            width = sortedWalls[0].length
            length = sortedWalls[1].length
        }
    }
    
    // Get room width in meters
    func getRoomWidth() -> Float {
        return width
    }
    
    // Get room length in meters
    func getRoomLength() -> Float {
        return length
    }
    
    // Calculate room area in square meters
    var roomArea: Float {
        return width * length
    }
}