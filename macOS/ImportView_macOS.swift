import SwiftUI
import UniformTypeIdentifiers

struct ImportView_macOS: View {
    @ObservedObject var roomStore: RoomStore
    @Binding var isPresented: Bool
    @State private var importSuccess = false
    @State private var importError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Import Rooms")
                .font(.title2)
                .fontWeight(.semibold)
            
            if importSuccess {
                // Success message
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("Import Successful")
                        .font(.headline)
                        .padding(.top, 5)
                }
                .padding()
            } else if importError {
                // Error message
                VStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    
                    Text("Import Failed")
                        .font(.headline)
                        .padding(.top, 5)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                // Instructions
                Text("Choose a JSON file containing your rooms data")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Select File") {
                    openImportPanel()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top)
            }
            
            Spacer()
            
            Button("Close") {
                isPresented = false
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .padding()
    }
    
    private func openImportPanel() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "Import Rooms"
        openPanel.message = "Choose a JSON file containing rooms data"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                importFile(from: url)
            }
        }
    }
    
    private func importFile(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let success = roomStore.importRoomsFromJSON(data)
            
            importSuccess = success
            importError = !success
            errorMessage = success ? "" : "The file does not contain valid room data."
        } catch {
            importError = true
            errorMessage = "Error reading file: \(error.localizedDescription)"
            print("Import error: \(error)")
        }
    }
}