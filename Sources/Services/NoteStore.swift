import Foundation
import Combine
import FileWatcher

@MainActor
final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    
    private let dbManager = DatabaseManager.shared
    private var fileWatcher: FileWatcher?
    
    init() {
        loadNotes()
        setupFileWatcher()
    }
    
    private func loadNotes() {
        notes = dbManager.fetchAllNotes()
    }
    
    private func setupFileWatcher() {
        // Watch for external file changes in the documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileWatcher = FileWatcher(paths: [documentsPath.path])
        
        fileWatcher?.callback = { [weak self] event in
            Task { @MainActor in
                self?.loadNotes()
            }
        }
    }
    
    func createNote() {
        let newNote = Note()
        dbManager.insertNote(newNote)
        notes.insert(newNote, at: 0)
    }
    
    func updateNote(id: UUID, title: String? = nil, content: String? = nil) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        
        var updatedNote = notes[index]
        if let title = title {
            updatedNote.title = title
        }
        if let content = content {
            updatedNote.content = content
        }
        updatedNote.updatedAt = Date()
        
        dbManager.updateNote(updatedNote)
        notes[index] = updatedNote
        
        // Re-sort by updated date
        notes.sort { $0.updatedAt > $1.updatedAt }
    }
    
    func deleteNote(id: UUID) {
        dbManager.deleteNote(id: id)
        notes.removeAll { $0.id == id }
    }
}
