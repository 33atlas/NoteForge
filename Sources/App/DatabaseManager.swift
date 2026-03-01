import Foundation
import SQLite

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    private let notes = Table("notes")
    
    // Column definitions
    private let id = Expression<String>("id")
    private let title = Expression<String>("title")
    private let content = Expression<String>("content")
    private let createdAt = Expression<Date>("created_at")
    private let updatedAt = Expression<Date>("updated_at")
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let path = getDatabasePath()
            db = try Connection(path)
            try createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    private func getDatabasePath() -> String {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("NoteForge", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appFolder.path) {
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        
        return appFolder.appendingPathComponent("noteforge.sqlite3").path
    }
    
    private func createTables() throws {
        try db?.run(notes.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(title)
            t.column(content)
            t.column(createdAt)
            t.column(updatedAt)
        })
    }
    
    // MARK: - CRUD Operations
    
    func fetchAllNotes() -> [Note] {
        var result: [Note] = []
        
        do {
            let query = notes.order(updatedAt.desc)
            for row in try db!.prepare(query) {
                let note = Note(
                    id: UUID(uuidString: row[id])!,
                    title: row[title],
                    content: row[content],
                    createdAt: row[createdAt],
                    updatedAt: row[updatedAt]
                )
                result.append(note)
            }
        } catch {
            print("Fetch error: \(error)")
        }
        
        return result
    }
    
    func saveNote(_ note: Note) {
        do {
            let insert = notes.insert(or: .replace,
                id <- note.id.uuidString,
                title <- note.title,
                content <- note.content,
                createdAt <- note.createdAt,
                updatedAt <- note.updatedAt
            )
            try db?.run(insert)
        } catch {
            print("Save error: \(error)")
        }
    }
    
    func deleteNote(_ note: Note) {
        do {
            let noteToDelete = notes.filter(id == note.id.uuidString)
            try db?.run(noteToDelete.delete())
        } catch {
            print("Delete error: \(error)")
        }
    }
    
    func deleteNote(id noteId: UUID) {
        do {
            let noteToDelete = notes.filter(id == noteId.uuidString)
            try db?.run(noteToDelete.delete())
        } catch {
            print("Delete error: \(error)")
        }
    }
}
