import SwiftUI
import CoreMotion

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Device Motion Data")
                .font(.title)
                .padding()
            
            Group {
                SensorDataView(title: "Accelerometer", 
                               xValue: motionManager.accelerometerData.x,
                               yValue: motionManager.accelerometerData.y,
                               zValue: motionManager.accelerometerData.z,
                               units: "G")
                
                Divider()
                
                SensorDataView(title: "Gyroscope", 
                               xValue: motionManager.gyroData.x,
                               yValue: motionManager.gyroData.y,
                               zValue: motionManager.gyroData.z,
                               units: "rad/s")
                
                Divider()
                
                SensorDataView(title: "Magnetometer", 
                               xValue: motionManager.magnetometerData.x,
                               yValue: motionManager.magnetometerData.y,
                               zValue: motionManager.magnetometerData.z,
                               units: "μT")
            }
            .padding(.horizontal)
        }
        .onAppear {
            motionManager.startUpdates()
        }
        .onDisappear {
            motionManager.stopUpdates()
        }
    }
}

struct SensorDataView: View {
    let title: String
    let xValue: Double
    let yValue: Double
    let zValue: Double
    let units: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    DataRow(label: "X", value: xValue, units: units)
                    DataRow(label: "Y", value: yValue, units: units)
                    DataRow(label: "Z", value: zValue, units: units)
                }
                
                Spacer()
                
                // Simple visual indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .offset(x: CGFloat(xValue * 30), y: CGFloat(yValue * 30))
                }
                .frame(width: 100, height: 100)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct DataRow: View {
    let label: String
    let value: Double
    let units: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .frame(width: 30, alignment: .leading)
            Text(String(format: "%.3f", value))
                .frame(width: 80, alignment: .trailing)
                .monospacedDigit()
            Text(units)
        }
    }
}

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    
    @Published var accelerometerData = (x: 0.0, y: 0.0, z: 0.0)
    @Published var gyroData = (x: 0.0, y: 0.0, z: 0.0)
    @Published var magnetometerData = (x: 0.0, y: 0.0, z: 0.0)
    
    init() {
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
    }
    
    func startUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    self?.accelerometerData = (data.acceleration.x, data.acceleration.y, data.acceleration.z)
                }
            }
        }
        
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1
            motionManager.startGyroUpdates(to: queue) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    self?.gyroData = (data.rotationRate.x, data.rotationRate.y, data.rotationRate.z)
                }
            }
        }
        
        if motionManager.isMagnetometerAvailable {
            motionManager.magnetometerUpdateInterval = 0.1
            motionManager.startMagnetometerUpdates(to: queue) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    self?.magnetometerData = (data.magneticField.x, data.magneticField.y, data.magneticField.z)
                }
            }
        }
    }
    
    func stopUpdates() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopMagnetometerUpdates()
    }
}
