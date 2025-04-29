import SwiftUI

struct RoomListView: View {
    @ObservedObject var roomStore: RoomStore
    @State private var showingAddRoom = false
    @State private var newRoomName = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(roomStore.rooms) { room in
                    NavigationLink(destination: RoomDetailView(room: room, roomStore: roomStore)) {
                        RoomRowView(room: room)
                    }
                }
                .onDelete(perform: deleteRooms)
            }
            .navigationTitle("Rooms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddRoom = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoom) {
                AddRoomView(roomStore: roomStore, isPresented: $showingAddRoom)
            }
        }
    }
    
    func deleteRooms(at offsets: IndexSet) {
        roomStore.deleteRoom(at: offsets)
    }
}

struct RoomRowView: View {
    let room: Room
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(room.name)
                .font(.headline)
            
            HStack {
                Text("\(Int(room.width)) × \(Int(room.length)) cm")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.1f m²", room.area))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddRoomView: View {
    @ObservedObject var roomStore: RoomStore
    @Binding var isPresented: Bool
    @State private var roomName = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Room Name")) {
                        TextField("Living Room, Kitchen, etc.", text: $roomName)
                    }
                }
                
                NavigationLink(destination: RoomScanView(roomName: roomName, roomStore: roomStore, isPresented: $isPresented)) {
                    Text("Start Measuring")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                }
                .disabled(roomName.isEmpty)
            }
            .navigationTitle("New Room")
            .navigationBarItems(leading: Button("Cancel") {
                isPresented = false
            })
        }
    }
}

struct RoomDetailView: View {
    let room: Room
    @ObservedObject var roomStore: RoomStore
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(room.name)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Image(systemName: "square.dashed")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                HStack(spacing: 40) {
                    VStack {
                        Text("WIDTH")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(room.width))")
                            .font(.system(size: 42, weight: .bold))
                        
                        Text("cm")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 120)
                    
                    VStack {
                        Text("LENGTH")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(room.length))")
                            .font(.system(size: 42, weight: .bold))
                        
                        Text("cm")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 120)
                }
                
                VStack {
                    Text("AREA")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.1f", room.area))
                        .font(.system(size: 42, weight: .bold))
                    
                    Text("m²")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            Spacer()
            
            VStack(spacing: 16) {
                NavigationLink(destination: RoomScanView(
                    roomName: room.name,
                    roomStore: roomStore, 
                    isPresented: .constant(false),
                    existingRoom: room
                )) {
                    Text("Remeasure Room")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Text("Delete Room")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Room"),
                message: Text("Are you sure you want to delete '\(room.name)'? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteRoom()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func deleteRoom() {
        if let index = roomStore.rooms.firstIndex(where: { $0.id == room.id }) {
            roomStore.deleteRoom(at: IndexSet(integer: index))
            presentationMode.wrappedValue.dismiss()
        }
    }
}