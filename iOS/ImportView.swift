import SwiftUI

struct ImportView: View {
    @ObservedObject var roomStore: RoomStore
    @Binding var isPresented: Bool
    @State private var jsonText = ""
    @State private var importError: String? = nil
    @State private var importSuccess = false
    
    var body: some View {
        NavigationView {
            VStack {
                if let error = importError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                if importSuccess {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .padding()
                        
                        Text("Rooms Successfully Imported!")
                            .font(.headline)
                            .padding(.bottom)
                    }
                } else {
                    Text("Paste your room JSON data below")
                        .font(.headline)
                        .padding(.top)
                    
                    TextEditor(text: $jsonText)
                        .padding()
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius:
                                            8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding()
                    
                    Button("Import") {
                        importRoomsFromText()
                    }
                    .disabled(jsonText.isEmpty)
                    .padding()
                    .foregroundColor(.white)
                    .background(jsonText.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Import Rooms")
            .navigationBarItems(leading: Button("Cancel") {
                isPresented = false
            }, trailing: importSuccess ? Button("Done") {
                isPresented = false
            } : nil)
        }
    }
    
    private func importRoomsFromText() {
        guard let jsonData = jsonText.data(using: .utf8) else {
            importError = "Invalid text data"
            return
        }
        
        let success = roomStore.importRoomsFromJSON(jsonData)
        
        if success {
            importSuccess = true
            importError = nil
        } else {
            importError = "Failed to import rooms. The JSON format may be invalid."
        }
    }
}