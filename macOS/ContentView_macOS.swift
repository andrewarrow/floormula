import SwiftUI

struct ContentView_macOS: View {
    @StateObject private var roomStore = RoomStore()
    @State private var selectedTab: Int? = 0
    @State private var previousTab = 0
    @State private var needsFloorplanRefresh = false
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(
                    destination: RoomListView_macOS(roomStore: roomStore),
                    tag: 0,
                    selection: $selectedTab
                ) {
                    Label("Rooms", systemImage: "list.bullet")
                }
                
                NavigationLink(
                    destination: FloorplanView_macOS(roomStore: roomStore)
                        .id(needsFloorplanRefresh ? UUID() : nil), // Force refresh when needed
                    tag: 1,
                    selection: $selectedTab
                ) {
                    Label("Floorplan", systemImage: "rectangle.3.group")
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("floormula")
            
            // Default content view when no selection is made
            Text("Select a view from the sidebar")
                .font(.title)
                .foregroundColor(.secondary)
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .onChange(of: selectedTab) { newValue in
            // If switching to Floorplan tab
            if let tab = newValue, tab == 1 && previousTab != 1 {
                // Reload rooms and refresh the view
                roomStore.loadRooms()
                roomStore.validateRooms()
                
                // Toggle ID to force view refresh
                needsFloorplanRefresh.toggle()
                
                print("Switched to Floorplan tab, rooms count: \(roomStore.rooms.count)")
            }
            
            if let tab = newValue {
                previousTab = tab
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}