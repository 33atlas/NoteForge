import Foundation
import SQLite

/// DatabaseManager handles SQLite storage for note metadata using SQLite.swift
final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    private let notes = Table("notes")
    
    // MARK: - Column Definitions
    
    // Core columns
    private let id = Expression<String>("id")
    private let title = Expression<String>("title")
    private let content = Expression<String>("content")
    private let createdAt = Expression<Date>("created_at")
    private let updatedAt = Expression<Date>("updated_at")
    
    // Extended columns
    private let tags = Expression<String>("tags")  // JSON array
    private let source = Expression<String>("source")
    private let isArchived = Expression<Bool>("is_archived")
    private let isPinned = Expression<Bool>("is_pinned")
    
    // Links stored as JSON
    private let links = Expression<String>("links")
    
    private init() {
        setupDatabase()
    }
    
    // MARK: - Setup
    
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
        // Notes table
        try db?.run(notes.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(title)
            t.column(content)
            t.column(createdAt)
            t.column(updatedAt)
            t.column(tags, defaultValue: "[]")
            t.column(source, defaultValue: "manual")
            t.column(isArchived, defaultValue: false)
            t.column(isPinned, defaultValue: false)
            t.column(links, defaultValue: "[]")
        })
        
        // Create indexes for common queries
        try db?.run(notes.createIndex(updatedAt, ifNotExists: true))
        try db?.run(notes.createIndex(isArchived, ifNotExists: true))
        try db?.run(notes.createIndex(isPinned, ifNotExists: true))
        
        // Tags table for efficient tag queries
        let tagsTable = Table("note_tags")
        let noteId = Expression<String>("note_id")
        let tagName = Expression<String>("tag_name")
        
        try db?.run(tagsTable.create(ifNotExists: true) { t in
            t.column(noteId)
            t.column(tagName)
            t.primaryKey(noteId, tagName)
        })
        try db?.run(tagsTable.createIndex(tagName, ifNotExists: true))
        
        // Links table for efficient link queries
        let linksTable = Table("note_links")
        let sourceNoteId = Expression<String>("source_note_id")
        let targetNoteId = Expression<String>("target_note_id")
        let targetTitle = Expression<String>("target_title")
        
        try db?.run(linksTable.create(ifNotExists: true) { t in
            t.column(sourceNoteId)
            t.column(targetNoteId)
            t.column(targetTitle)
            t.primaryKey(sourceNoteId, targetTitle)
        })
    }
    
    // MARK: - CRUD Operations
    
    /// Fetch all notes ordered by update date
    func fetchAllNotes() -> [Note] {
        var result: [Note] = []
        do {
            guard let db = db else { return [] }
            for row in try db.prepare(notes.order(updatedAt.desc)) {
                let note = noteFromRow(row)
                result.append(note)
            }
        } catch {
            print("Fetch error: \(error)")
        }
        return result
    }
    
    /// Fetch a single note by ID
    func fetchNote(byId noteId: UUID) -> Note? {
        do {
            guard let db = db else { return nil }
            let query = notes.filter(id == noteId.uuidString)
            if let row = try db.pluck(query) {
                return noteFromRow(row)
            }
        } catch {
            print("Fetch note error: \(error)")
        }
        return nil
    }
    
    /// Save a note (insert or replace)
    func saveNote(_ note: Note) {
        do {
            let tagsJSON = try JSONEncoder().encode(note.tags)
            let linksJSON = try JSONEncoder().encode(note.links)
            
            let insert = notes.insert(or: .replace,
                id <- note.id.uuidString,
                title <- note.title,
                content <- note.content,
                createdAt <- note.createdAt,
                updatedAt <- note.updatedAt,
                tags <- String(data: tagsJSON, encoding: .utf8) ?? "[]",
                source <- note.source.rawValue,
                isArchived <- note.isArchived,
                isPinned <- note.isPinned,
                links <- String(data: linksJSON, encoding: .utf8) ?? "[]"
            )
            try db?.run(insert)
            
            // Update tags table
            updateTagsTable(for: note)
            
            // Update links table
            updateLinksTable(for: note)
            
        } catch {
            print("Save error: \(error)")
        }
    }
    
    /// Delete a note by ID
    func deleteNote(_ noteId: UUID) {
        do {
            let note = notes.filter(id == noteId.uuidString)
            try db?.run(note.delete())
            
            // Clean up tags
            let tagsTable = Table("note_tags")
            try db?.run(tagsTable.filter(Expression<String>("note_id") == noteId.uuidString).delete())
            
            // Clean up links
            let linksTable = Table("note_links")
            try db?.run(linksTable.filter(Expression<String>("source_note_id") == noteId.uuidString).delete())
            
        } catch {
            print("Delete error: \(error)")
        }
    }
    
    // MARK: - Tag Queries
    
    /// Get all unique tags
    func fetchAllTags() -> [String] {
        var tags: [String] = []
        do {
            guard let db = db else { return [] }
            let tagsTable = Table("note_tags")
            for row in try db.prepare(tagsTable.select(distinct: Expression<String>("tag_name"))) {
                tags.append(row[Expression<String>("tag_name")])
            }
        } catch {
            print("Fetch tags error: \(error)")
        }
        return tags.sorted()
    }
    
    /// Get notes with a specific tag
    func fetchNotes(withTag tag: String) -> [Note] {
        var result: [Note] = []
        do {
            guard let db = db else { return [] }
            let tagsTable = Table("note_tags")
            let noteIds = try db.prepare(tagsTable.filter(Expression<String>("tag_name") == tag))
                .map { $0[Expression<String>("note_id")] }
            
            for noteIdString in noteIds {
                if let note = fetchNote(byId: UUID(uuidString: noteIdString) ?? UUID()) {
                    result.append(note)
                }
            }
        } catch {
            print("Fetch notes by tag error: \(error)")
        }
        return result
    }
    
    /// Search notes by title or content
    func searchNotes(query searchQuery: String) -> [Note] {
        var result: [Note] = []
        let pattern = "%\(searchQuery)%"
        do {
            guard let db = db else { return [] }
            let query = notes.filter(title.like(pattern) || content.like(pattern))
            for row in try db.prepare(query) {
                result.append(noteFromRow(row))
            }
        } catch {
            print("Search error: \(error)")
        }
        return result
    }
    
    /// Get notes that link to a specific note
    func fetchNoteslinkingTo(_ noteId: UUID) -> [Note] {
        var result: [Note] = []
        do {
            guard let db = db else { return [] }
            let linksTable = Table("note_links")
            let sourceIds = try db.prepare(linksTable.filter(Expression<String>("target_note_id") == noteId.uuidString))
                .map { $0[Expression<String>("source_note_id")] }
            
            for noteIdString in sourceIds {
                if let note = fetchNote(byId: UUID(uuidString: noteIdString) ?? UUID()) {
                    result.append(note)
                }
            }
        } catch {
            print("Fetch linking notes error: \(error)")
        }
        return result
    }
    
    /// Get notes linked from a specific note
    func fetchNotesLinkedFrom(_ noteId: UUID) -> [Note] {
        var result: [Note] = []
        do {
            guard let db = db else { return [] }
            let linksTable = Table("note_links")
            let targetIds = try db.prepare(linksTable.filter(Expression<String>("source_note_id") == noteId.uuidString))
                .compactMap { $0[Expression<String>("target_note_id")] }
            
            for noteIdString in targetIds {
                if let note = fetchNote(byId: UUID(uuidString: noteIdString) ?? UUID()) {
                    result.append(note)
                }
            }
        } catch {
            print("Fetch linked notes error: \(error)")
        }
        return result
    }
    
    // MARK: - Helper Methods
    
    private func noteFromRow(_ row: Row) -> Note {
        let tagsJSON = row[tags]
        let linksJSON = row[links]
        
        let decodedTags: [String] = (try? JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))) ?? []
        let decodedLinks: [NoteLink] = (try? JSONDecoder().decode([NoteLink].self, from: Data(linksJSON.utf8))) ?? []
        
        return Note(
            id: UUID(uuidString: row[id]) ?? UUID(),
            title: row[title],
            content: row[content],
            createdAt: row[createdAt],
            updatedAt: row[updatedAt],
            tags: decodedTags,
            links: decodedLinks,
            source: NoteSource(rawValue: row[source]) ?? .manual,
            isArchived: row[isArchived],
            isPinned: row[isPinned]
        )
    }
    
    private func updateTagsTable(for note: Note) {
        do {
            let tagsTable = Table("note_tags")
            // Remove existing tags for this note
            try db?.run(tagsTable.filter(Expression<String>("note_id") == note.id.uuidString).delete())
            
            // Insert new tags
            for tag in note.tags {
                try db?.run(tagsTable.insert(
                    Expression<String>("note_id") <- note.id.uuidString,
                    Expression<String>("tag_name") <- tag
                ))
            }
        } catch {
            print("Update tags table error: \(error)")
        }
    }
    
    private func updateLinksTable(for note: Note) {
        do {
            let linksTable = Table("note_links")
            // Remove existing links for this note
            try db?.run(linksTable.filter(Expression<String>("source_note_id") == note.id.uuidString).delete())
            
            // Insert new links
            for link in note.links {
                try db?.run(linksTable.insert(
                    Expression<String>("source_note_id") <- note.id.uuidString,
                    Expression<String>("target_note_id") <- link.targetNoteId?.uuidString ?? "",
                    Expression<String>("target_title") <- link.targetTitle
                ))
            }
        } catch {
            print("Update links table error: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
