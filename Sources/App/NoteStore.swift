import Foundation
import Combine
import FileWatcher
import AppKit

final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    
    private let db = DatabaseManager.shared
    private var fileWatcher: FileWatcher?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadNotes()
        setupFileWatcher()
    }
    
    private func loadNotes() {
        notes = db.fetchAllNotes()
    }
    
    private func setupFileWatcher() {
        // Watch for external file changes if needed
        let notesPath = getNotesDirectory()
        
        fileWatcher = FileWatcher(path: notesPath)
        fileWatcher?.callback = { [weak self] event in
            DispatchQueue.main.async {
                self?.loadNotes()
            }
        }
        fileWatcher?.start()
    }
    
    private func getNotesDirectory() -> String {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("NoteForge").path
    }
    
    // MARK: - Note Operations
    
    func createNote() -> Note {
        let note = Note()
        notes.insert(note, at: 0)
        db.saveNote(note)
        return note
    }
    
    func saveNote(_ note: Note) {
        var updatedNote = note
        updatedNote.updatedAt = Date()
        
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = updatedNote
        }
        
        db.saveNote(updatedNote)
    }
    
    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        db.deleteNote(id: note.id)
    }
    
    func deleteNote(at offsets: IndexSet) {
        for index in offsets {
            let note = notes[index]
            db.deleteNote(id: note.id)
        }
        notes.remove(atOffsets: offsets)
    }
    
    func updateNote(_ note: Note) {
        saveNote(note)
    }
}
