import SwiftUI
import UniformTypeIdentifiers

struct RoomListView_macOS: View {
    @ObservedObject var roomStore: RoomStore
    @State private var showingAddRoom = false
    @State private var newRoomName = ""
    @State private var showingImportView = false
    @State private var showingExportView = false
    @State private var selectedRoomId: UUID? = nil
    
    var body: some View {
        VStack {
            if roomStore.rooms.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(roomStore.rooms) { room in
                        RoomRowView(room: room, isSelected: selectedRoomId == room.id)
                            .onTapGesture {
                                selectedRoomId = room.id
                            }
                    }
                    .onDelete(perform: deleteRooms)
                }
                .listStyle(InsetListStyle())
            }
            
            Spacer()
            
            // Bottom toolbar
            HStack {
                Button(action: {
                    showingAddRoom = true
                }) {
                    Label("Add Room", systemImage: "plus")
                }
                
                Spacer()
                
                Button(action: {
                    showingImportView = true
                }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                
                Button(action: {
                    exportRooms()
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            .padding()
        }
        .navigationTitle("Rooms")
        // Add Room sheet
        .sheet(isPresented: $showingAddRoom) {
            VStack(spacing: 20) {
                Text("Add New Room")
                    .font(.headline)
                
                TextField("Room Name", text: $newRoomName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Text("Note: For macOS, you'll need to manually enter room dimensions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack {
                    Button("Cancel") {
                        newRoomName = ""
                        showingAddRoom = false
                    }
                    
                    Spacer()
                    
                    Button("Add Room") {
                        if !newRoomName.isEmpty {
                            addNewRoomManually()
                        }
                    }
                    .disabled(newRoomName.isEmpty)
                }
                .padding()
            }
            .frame(width: 300, height: 200)
            .padding()
        }
        // Import sheet will be implemented to use NSSavePanel
        
        // For manually entering room dimensions when adding a new room
        .sheet(isPresented: $showingImportView) {
            ImportView_macOS(roomStore: roomStore, isPresented: $showingImportView)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "house")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Rooms Added")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Tap the + button to add your first room")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showingAddRoom = true
            }) {
                Text("Add Room")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func deleteRooms(at offsets: IndexSet) {
        roomStore.deleteRoom(at: offsets)
    }
    
    // Function to handle manual room creation (since AR scanning is not available)
    private func addNewRoomManually() {
        // Create a room with default dimensions which can be edited later
        let newRoom = Room(
            name: newRoomName,
            width: 300, // 3m default width
            length: 400  // 4m default length
        )
        
        roomStore.addRoom(room: newRoom)
        newRoomName = ""
        showingAddRoom = false
    }
    
    private func exportRooms() {
        // Implementation will use NSSavePanel for macOS
        showingExportView = true
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "rooms.json"
        savePanel.title = "Export Rooms"
        savePanel.message = "Choose a location to save your rooms data"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(self.roomStore.rooms)
                    try data.write(to: url)
                    print("Exported rooms successfully to \(url.path)")
                } catch {
                    print("Error exporting rooms: \(error)")
                }
            }
        }
    }
}

struct RoomRowView: View {
    let room: Room
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(room.name)
                    .font(.headline)
                
                HStack {
                    Text(String(format: "%.1f m × %.1f m", room.width / 100, room.length / 100))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.1f m²", room.area))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Visual representation of room proportions
            RoomProportionView(room: room)
                .frame(width: 60, height: 40)
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

struct RoomProportionView: View {
    let room: Room
    
    var body: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.2))
            .overlay(
                Rectangle()
                    .stroke(Color.blue, lineWidth: 1)
            )
            .aspectRatio(CGFloat(room.width / room.length), contentMode: .fit)
            .rotationEffect(.degrees(Double(room.rotation)))
    }
}