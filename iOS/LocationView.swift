import SwiftUI
import CoreLocation

struct LocationContentView: View {
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Location Data")
                .font(.title)
                .padding()
            
            Group {
                if locationManager.authorizationStatus == .denied ||
                   locationManager.authorizationStatus == .restricted {
                    Text("Location access is denied or restricted.\nPlease enable location services in Settings.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    LocationInfoView(title: "Position", 
                                    items: [
                                        ("Latitude", String(format: "%.6f°", locationManager.latitude)),
                                        ("Longitude", String(format: "%.6f°", locationManager.longitude)),
                                        ("Altitude", String(format: "%.1f m", locationManager.altitude))
                                    ])
                    
                    Divider()
                    
                    LocationInfoView(title: "Direction", 
                                    items: [
                                        ("Heading", String(format: "%.1f°", locationManager.headingDirection)),
                                        ("Accuracy", "\(locationManager.compassAccuracy)°"),
                                        ("Course", String(format: "%.1f°", locationManager.course))
                                    ])
                    
                    Divider()
                    
                    LocationInfoView(title: "Movement", 
                                    items: [
                                        ("Speed", String(format: "%.1f m/s", locationManager.speed)),
                                        ("", ""),
                                        ("", "")
                                    ])
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .onAppear {
            locationManager.startUpdates()
        }
        .onDisappear {
            locationManager.stopUpdates()
        }
    }
}

struct LocationInfoView: View {
    let title: String
    let items: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            ForEach(items, id: \.0) { item in
                if !item.0.isEmpty {
                    HStack {
                        Text("\(item.0):")
                            .frame(width: 100, alignment: .leading)
                        Text(item.1)
                            .frame(minWidth: 100, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}