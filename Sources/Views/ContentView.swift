import SwiftUI

struct ContentView: View {
    @EnvironmentObject var noteStore: NoteStore
    @State private var selectedNoteId: UUID?
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            // Notes List
            List(selection: $selectedNoteId) {
                ForEach(filteredNotes) { note in
                    NoteRowView(note: note)
                        .tag(note.id)
                }
                .onDelete(perform: deleteNotes)
            }
            .listStyle(.sidebar)
            
            // New Note Button
            Button(action: { noteStore.createNote() }) {
                Label("New Note", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .padding()
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let noteId = selectedNoteId,
           let note = noteStore.notes.first(where: { $0.id == noteId }) {
            NoteEditorView(note: note)
                .environmentObject(noteStore)
        } else {
            VStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
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
    
    private func deleteNotes(at offsets: IndexSet) {
        noteStore.deleteNotes(at: offsets)
    }
}

struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(note.content.prefix(50))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text(note.formattedDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct NoteEditorView: View {
    let note: Note
    @EnvironmentObject var noteStore: NoteStore
    @State private var title: String = ""
    @State private var content: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Field
            TextField("Note Title", text: $title)
                .font(.title)
                .textFieldStyle(.plain)
                .padding()
                .onChange(of: title) { _, newValue in
                    noteStore.updateNoteTitle(note.id, title: newValue)
                }
            
            Divider()
            
            // Content Editor
            TextEditor(text: $content)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding()
                .onChange(of: content) { _, newValue in
                    noteStore.updateNoteContent(note.id, content: newValue)
                }
            
            Divider()
            
            // Preview
            if !content.isEmpty {
                ScrollView {
                    MarkdownPreviewView(content: content)
                        .padding()
                }
                .frame(maxHeight: 200)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .onAppear {
            title = note.title
            content = note.content
        }
    }
}

struct MarkdownPreviewView: View {
    let content: String
    
    var body: some View {
        Text(AttributedString(markdown: content))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore())
}
