import Foundation
import Combine

final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    
    private let database = DatabaseManager.shared
    
    init() {
        loadNotes()
    }
    
    func loadNotes() {
        notes = database.fetchAllNotes()
    }
    
    func createNote() {
        let note = Note()
        notes.insert(note, at: 0)
        database.saveNote(note)
    }
    
    func saveNote(_ note: Note) {
        var updatedNote = note
        updatedNote.updatedAt = Date()
        database.saveNote(updatedNote)
        
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = updatedNote
        }
        
        // Re-sort by updated date
        notes.sort { $0.updatedAt > $1.updatedAt }
    }
    
    func deleteNote(_ note: Note) {
        database.deleteNote(note.id)
        notes.removeAll { $0.id == note.id }
    }
}
