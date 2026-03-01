import SwiftUI
import Ink

struct ContentView: View {
    @EnvironmentObject var noteStore: NoteStore
    @State private var selectedNote: Note?
    @State private var searchText = ""
    
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return noteStore.notes
        }
        return noteStore.notes.filter { note in
            note.title.localizedCaseInsensitiveContains(searchText) ||
            note.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(filteredNotes, selection: $selectedNote) { note in
                NoteRowView(note: note)
                    .tag(note)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 250)
            .searchable(text: $searchText, prompt: "Search notes")
            
            if let note = selectedNote {
                NoteEditorView(note: note)
            } else {
                Text("Select a note or create a new one")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(note.preview)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text(note.formattedDate)
                .font(.caption2)
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct NoteEditorView: View {
    @ObservedObject var note: Note
    @EnvironmentObject var noteStore: NoteStore
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $note.title)
                .font(.title2)
                .textFieldStyle(.plain)
                .padding()
            
            Divider()
            
            TextEditor(text: $note.content)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
        .onChange(of: note.content) { _, _ in
            noteStore.saveNote(note)
        }
        .onChange(of: note.title) { _, _ in
            noteStore.saveNote(note)
        }
    }
}
