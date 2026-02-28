import SwiftUI
import Markdown

struct NoteEditorView: View {
    @EnvironmentObject var noteStore: NoteStore
    @State private var editedTitle: String = ""
    @State private var editedContent: String = ""
    @State private var showPreview: Bool = false
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        if let note = noteStore.selectedNote {
            VStack(spacing: 0) {
                // Title
                TextField("Note Title", text: $editedTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .focused($isTitleFocused)
                    .onChange(of: editedTitle) { _, newValue in
                        var updatedNote = note
                        updatedNote.title = newValue
                        noteStore.updateNote(updatedNote)
                    }
                
                // Toolbar
                HStack {
                    // Tags
                    HStack(spacing: 4) {
                        ForEach(note.tags, id: \.self) { tag in
                            TagView(tag: tag) {
                                noteStore.removeTagFromNote(tag, note: note)
                            }
                        }
                        
                        Menu {
                            ForEach(noteStore.tags.filter { !note.tags.contains($0.name) }, id: \.name) { tag in
                                Button(tag.name) {
                                    noteStore.addTagToNote(tag.name, note: note)
                                }
                            }
                            Divider()
                            TextField("New tag", onCommit: { newTag in
                                if !newTag.isEmpty {
                                    noteStore.addTagToNote(newTag, note: note)
                                }
                            })
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                    }
                    
                    Spacer()
                    
                    // Source badge
                    Label(note.source.displayName, systemImage: note.source.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    
                    // Preview toggle
                    Toggle(isOn: $showPreview) {
                        Image(systemName: "eye")
                    }
                    .toggleStyle(.button)
                    
                    // Delete
                    Button(action: {
                        noteStore.deleteNote(note)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                Divider()
                
                // Content editor
                if showPreview {
                    ScrollView {
                        MarkdownPreviewView(content: editedContent)
                            .padding(20)
                    }
                } else {
                    TextEditor(text: $editedContent)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .onChange(of: editedContent) { _, newValue in
                            var updatedNote = note
                            updatedNote.content = newValue
                            noteStore.updateNote(updatedNote)
                        }
                }
                
                // Status bar
                HStack {
                    Text("\(editedContent.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Modified \(note.modifiedAt, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .onAppear {
                editedTitle = note.title
                editedContent = note.content
            }
            .onChange(of: noteStore.selectedNote) { _, newNote in
                if let newNote = newNote {
                    editedTitle = newNote.title
                    editedContent = newNote.content
                }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                Text("Select a note")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("or create a new one")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button("New Note") {
                    noteStore.createNote()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct TagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            Text("#\(tag)")
                .font(.caption)
                .foregroundColor(.blue)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
    }
}

struct MarkdownPreviewView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseMarkdown(content), id: \.self) { block in
                block
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> [Text] {
        // Simple markdown parsing - in production use a proper library
        let lines = text.components(separatedBy: .newlines)
        
        return lines.map { line in
            var text = Text(line)
            
            // Headers
            if line.hasPrefix("### ") {
                text = Text(line.replacingOccurrences(of: "### ", with: ""))
                    .font(.headline)
            } else if line.hasPrefix("## ") {
                text = Text(line.replacingOccurrences(of: "## ", with: ""))
                    .font(.title2)
                    .fontWeight(.bold)
            } else if line.hasPrefix("# ") {
                text = Text(line.replacingOccurrences(of: "# ", with: ""))
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            // Bold
            if line.contains("**") {
                // Simple bold handling - just show the text for now
            }
            
            return text
        }
    }
}
