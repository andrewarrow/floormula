import SwiftUI

struct ContentView: View {
    @StateObject private var roomStore = RoomStore()
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var needsFloorplanRefresh = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RoomListView(roomStore: roomStore)
                .tabItem {
                    Label("Rooms", systemImage: "list.bullet")
                }
                .tag(0)
            
            FloorplanView(roomStore: roomStore)
                .id(needsFloorplanRefresh ? UUID() : nil) // Force refresh when needed
                .tabItem {
                    Label("Floorplan", systemImage: "rectangle.3.group")
                }
                .tag(1)
        }
        .onChange(of: selectedTab) { newValue in
            // If switching to Floorplan tab
            if newValue == 1 && previousTab != 1 {
                // Reload rooms and refresh the view
                roomStore.loadRooms()
                roomStore.validateRooms()
                
                // Toggle ID to force view refresh
                needsFloorplanRefresh.toggle()
                
                print("Switched to Floorplan tab, rooms count: \(roomStore.rooms.count)")
            }
            
            previousTab = newValue
        }
    }
}
