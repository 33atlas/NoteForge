import Foundation
import SQLite

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    
    // Table definitions
    private let notes = Table("notes")
    private let id = SQLite.Expression<String>("id")
    private let title = SQLite.Expression<String>("title")
    private let content = SQLite.Expression<String>("content")
    private let createdAt = SQLite.Expression<Date>("created_at")
    private let updatedAt = SQLite.Expression<Date>("updated_at")
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let path = getDocumentsDirectory().appendingPathComponent("noteforge.sqlite3").path
            db = try Connection(path)
            try createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    private func createTables() throws {
        try db?.run(notes.create(ifNotExists: true) { table in
            table.column(id, primaryKey: true)
            table.column(title)
            table.column(content)
            table.column(createdAt)
            table.column(updatedAt)
        })
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // CRUD Operations
    
    func fetchAllNotes() -> [Note] {
        var result: [Note] = []
        do {
            guard let db = db else { return [] }
            for row in try db.prepare(notes.order(updatedAt.desc)) {
                let note = Note(
                    id: UUID(uuidString: row[id]) ?? UUID(),
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
    
    func insertNote(_ note: Note) {
        do {
            try db?.run(notes.insert(
                id <- note.id.uuidString,
                title <- note.title,
                content <- note.content,
                createdAt <- note.createdAt,
                updatedAt <- note.updatedAt
            ))
        } catch {
            print("Insert error: \(error)")
        }
    }
    
    func updateNote(_ note: Note) {
        let target = notes.filter(id == note.id.uuidString)
        do {
            try db?.run(target.update(
                title <- note.title,
                content <- note.content,
                updatedAt <- Date()
            ))
        } catch {
            print("Update error: \(error)")
        }
    }
    
    func deleteNote(id noteId: UUID) {
        let target = notes.filter(id == noteId.uuidString)
        do {
            try db?.run(target.delete())
        } catch {
            print("Delete error: \(error)")
        }
    }
}
