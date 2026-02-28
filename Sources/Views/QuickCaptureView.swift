import SwiftUI

struct QuickCaptureView: View {
    @EnvironmentObject var noteStore: NoteStore
    @Environment(\.dismiss) var dismiss
    @State private var content: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Capture")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Content input
            TextField("What's on your mind?", text: $content, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(5...10)
                .padding()
                .focused($isFocused)
                .onSubmit {
                    saveNote()
                }
            
            Divider()
            
            // Actions
            HStack {
                Button(action: { /* Voice capture */ }) {
                    Label("Voice", systemImage: "mic")
                }
                .buttonStyle(.borderless)
                
                Button(action: { /* URL capture */ }) {
                    Label("URL", systemImage: "link")
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    saveNote()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 250)
        .onAppear {
            isFocused = true
        }
    }
    
    private func saveNote() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            noteStore.quickCapture(content: trimmed)
        }
    }
}
