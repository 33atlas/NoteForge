import SwiftUI
import Ink

struct ContentView: View {
    @EnvironmentObject var noteStore: NoteStore
    @State private var selectedNoteId: UUID?
    @State private var searchText: String = ""
    
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
            List(filteredNotes, selection: $selectedNoteId) { note in
                NoteRowView(note: note)
                    .tag(note.id)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .searchable(text: $searchText, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { noteStore.createNote() }) {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            if let selectedId = selectedNoteId,
               let note = noteStore.notes.first(where: { $0.id == selectedId }) {
                NoteDetailView(note: note)
            } else {
                ContentUnavailableView(
                    "No Note Selected",
                    systemImage: "doc.text",
                    description: Text("Select a note from the sidebar or create a new one")
                )
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.headline)
                .lineLimit(1)
            Text(note.content.isEmpty ? "No content" : note.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text(note.updatedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct NoteDetailView: View {
    @EnvironmentObject var noteStore: NoteStore
    let note: Note
    
    @State private var title: String
    @State private var content: String
    
    init(note: Note) {
        self.note = note
        _title = State(initialValue: note.title)
        _content = State(initialValue: note.content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $title)
                .font(.title)
                .textFieldStyle(.plain)
                .padding()
                .onChange(of: title) { _, newValue in
                    noteStore.updateNote(id: note.id, title: newValue)
                }
            
            Divider()
            
            TextEditor(text: $content)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding()
                .onChange(of: content) { _, newValue in
                    noteStore.updateNote(id: note.id, content: newValue)
                }
            
            Divider()
            
            HStack {
                if !content.isEmpty {
                    let markdown = try? MarkdownParser().html(from: content)
                    Text("Preview: \(markdown?.isEmpty == false ? "Available" : "None")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Last updated: \(note.updatedAt, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore())
}
