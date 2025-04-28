# Walls I Am In

An iOS app that maps room layouts by detecting when your device touches walls. Similar to apps like RoomScan Pro, but with a focus on simplicity and accuracy.

## Features

- Touch walls with your device to map room layouts
- Utilizes accelerometer, gyroscope and magnetometer for impact detection
- Automatically calculates room area and perimeter
- Visual representation of the mapped room
- Haptic and audio feedback when walls are detected
- Debug mode for sensor visualization

## Technical Implementation

The app is built using:

- SwiftUI for the user interface
- MVVM architecture pattern
- Core Motion for sensor data processing
- Core Location for device orientation
- ARKit (optional) for enhanced spatial tracking
- Sensor fusion algorithms for wall detection

## How It Works

1. Press "Start Scan" to begin the mapping process
2. Touch your device against each wall of the room
3. The app detects the impact and records the wall position
4. Continue until you've mapped all walls
5. Press "Stop Scan" to finalize the room
6. The app calculates and displays the room measurements

## Requirements

- iOS 17.0+
- iPhone with accelerometer, gyroscope, and compass
- Access to motion and location permissions

## Installation

1. Clone the repository
2. Open the project in Xcode
3. Build and run on a physical device (simulator won't have sensor data)

## Future Enhancements

- Enhanced AR integration for more accurate spatial mapping
- Floor plan export options (PDF, CAD, etc.)
- Multiple room support
- Furniture placement and visualization
- Machine learning for improved wall detection