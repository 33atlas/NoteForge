import SwiftUI

struct ContentView: View {
    @EnvironmentObject var noteStore: NoteStore
    @State private var selectedNoteId: UUID?
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private var sidebar: some View {
        List(selection: $selectedNoteId) {
            ForEach(filteredNotes) { note in
                NoteRowView(note: note)
                    .tag(note.id)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search notes")
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { noteStore.createNote() }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    private var detailView: some View {
        Group {
            if let noteId = selectedNoteId,
               let note = noteStore.notes.first(where: { $0.id == noteId }) {
                NoteEditorView(note: note)
            } else {
                Text("Select a note or create a new one")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return noteStore.notes
        }
        return noteStore.notes.filter { note in
            note.title.localizedCaseInsensitiveContains(searchText) ||
            note.content.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.headline)
                .lineLimit(1)
            Text(note.updatedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
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
                .font(.title)
                .textFieldStyle(.plain)
                .padding()
            
            Divider()
            
            TextEditor(text: $note.content)
                .font(.body)
                .padding()
                .onChange(of: note.content) { _, _ in
                    noteStore.saveNote(note)
                }
                .onChange(of: note.title) { _, _ in
                    noteStore.saveNote(note)
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore())
}
