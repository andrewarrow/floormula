import Foundation
import UIKit
import simd

// Data model for a wall point
struct WallPoint {
    var position: CGPoint
    var orientation: SIMD3<Float>
    var heading: Double
    var timestamp: Date
}

// Data model for a complete room
class RoomModel {
    var wallPoints: [WallPoint] = []
    var isClosed: Bool = false
    
    // Room measurements
    private(set) var area: Double = 0
    private(set) var perimeter: Double = 0
    private(set) var averageWallLength: Double = 0
    
    // Add a new wall point to the room
    func addWallPoint(_ point: WallPoint) {
        wallPoints.append(point)
        
        // Check if the room is potentially closed
        if wallPoints.count > 3 {
            checkRoomClosure()
        }
        
        // Recalculate measurements
        calculateMeasurements()
    }
    
    // Reset the room model
    func reset() {
        wallPoints.removeAll()
        isClosed = false
        area = 0
        perimeter = 0
        averageWallLength = 0
    }
    
    // Check if the latest point forms a closed loop with the first point
    private func checkRoomClosure() {
        guard wallPoints.count > 3 else { return }
        
        let firstPoint = wallPoints[0].position
        let latestPoint = wallPoints.last!.position
        
        // Calculate distance between first and last points
        let distance = hypot(latestPoint.x - firstPoint.x, latestPoint.y - firstPoint.y)
        
        // If the distance is small enough, consider the room closed
        // This threshold would need tuning in a real app
        if distance < 1.0 {
            isClosed = true
        }
    }
    
    // Calculate room measurements
    private func calculateMeasurements() {
        calculatePerimeter()
        calculateArea()
        calculateAverageWallLength()
    }
    
    // Calculate perimeter length
    private func calculatePerimeter() {
        guard wallPoints.count > 1 else {
            perimeter = 0
            return
        }
        
        var totalLength: Double = 0
        
        // Sum the distances between each consecutive pair of points
        for i in 0..<wallPoints.count {
            let point1 = wallPoints[i].position
            let point2 = wallPoints[(i + 1) % wallPoints.count].position
            
            let distance = hypot(point2.x - point1.x, point2.y - point1.y)
            totalLength += Double(distance)
        }
        
        perimeter = totalLength
    }
    
    // Calculate the enclosed area
    private func calculateArea() {
        guard wallPoints.count > 2 else {
            area = 0
            return
        }
        
        // Implementation of the Shoelace formula (Gauss's area formula)
        var sum: Double = 0
        
        for i in 0..<wallPoints.count {
            let p1 = wallPoints[i].position
            let p2 = wallPoints[(i + 1) % wallPoints.count].position
            
            sum += Double(p1.x * p2.y - p2.x * p1.y)
        }
        
        area = abs(sum) / 2.0
    }
    
    // Calculate average wall length
    private func calculateAverageWallLength() {
        guard wallPoints.count > 1 else {
            averageWallLength = 0
            return
        }
        
        averageWallLength = perimeter / Double(wallPoints.count)
    }
    
    // Get formatted area string with units
    func formattedArea() -> String {
        return String(format: "%.1f m²", area)
    }
    
    // Get formatted perimeter string with units
    func formattedPerimeter() -> String {
        return String(format: "%.1f m", perimeter)
    }
}