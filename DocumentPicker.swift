import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onDocumentsPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        // This is important - it ensures the app can access files from anywhere
        picker.shouldShowFileExtensions = true
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Start security-scoped resource access
            guard let url = urls.first else {
                parent.onDocumentsPicked([])
                return
            }
            
            // Get security-scoped access for the URL
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            
            // Send the URLs to the parent
            parent.onDocumentsPicked(urls)
            
            // Release the security-scoped resource
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onDocumentsPicked([])
        }
    }
}