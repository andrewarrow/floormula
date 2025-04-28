import SwiftUI

struct ContentView: View {
    @StateObject private var roomStore = RoomStore()
    
    var body: some View {
        TabView {
            RoomListView(roomStore: roomStore)
                .tabItem {
                    Label("Rooms", systemImage: "list.bullet")
                }
            
            FloorplanView(roomStore: roomStore)
                .tabItem {
                    Label("Floorplan", systemImage: "rectangle.3.group")
                }
        }
    }
}