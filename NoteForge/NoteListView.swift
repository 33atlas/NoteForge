import SwiftUI

struct NoteListView: View {
    @EnvironmentObject var noteStore: NoteStore
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search notes...", text: $noteStore.searchText)
                    .textFieldStyle(.plain)
                
                if !noteStore.searchText.isEmpty {
                    Button(action: { noteStore.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Notes list
            if noteStore.filteredNotes.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No notes yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Create a new note to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("New Note") {
                        noteStore.createNote()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(selection: $noteStore.selectedNote) {
                    ForEach(noteStore.filteredNotes) { note in
                        NoteRowView(note: note)
                            .tag(note)
                            .contextMenu {
                                Button("Delete") {
                                    noteStore.deleteNote(note)
                                }
                                Divider()
                                Button("Duplicate") {
                                    _ = noteStore.createNote(
                                        title: note.title + " (Copy)",
                                        content: note.content
                                    )
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 280)
    }
}

struct NoteRowView: View {
    let note: Note
    @EnvironmentObject var noteStore: NoteStore
    
    private var displayNotes: [Note] {
        noteStore.todayNotes
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: note.source.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(note.preview)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                ForEach(note.tags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(note.modifiedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
