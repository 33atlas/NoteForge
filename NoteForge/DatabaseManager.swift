import Foundation
import SQLite

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    private let notes = Table("notes")
    
    // Columns
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
            let path = getDocumentsDirectory().appendingPathComponent("noteforge.sqlite3").path
            db = try Connection(path)
            try createTables()
        } catch {
            print("Database setup error: \(error)")
        }
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
    
    func deleteNote(_ noteId: UUID) {
        do {
            let note = notes.filter(id == noteId.uuidString)
            try db?.run(note.delete())
        } catch {
            print("Delete error: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
