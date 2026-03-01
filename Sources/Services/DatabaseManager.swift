import Foundation
import SQLite

// MARK: - DatabaseManager

/// DatabaseManager handles SQLite storage for note metadata
final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    
    // MARK: - Table Definitions
    
    // Notes table
    private let notes = Table("notes")
    private let colId = SQLite.Expression<String>("id")
    private let colTitle = SQLite.Expression<String>("title")
    private let colContent = SQLite.Expression<String>("content")
    private let colAiSummary = SQLite.Expression<String?>("ai_summary")
    private let colCreatedAt = SQLite.Expression<Double>("created_at")
    private let colModifiedAt = SQLite.Expression<Double>("modified_at")
    private let colSource = SQLite.Expression<String>("source")
    private let colFolderPath = SQLite.Expression<String?>("folder_path")
    private let colIsArchived = SQLite.Expression<Bool>("is_archived")
    private let colIsPinned = SQLite.Expression<Bool>("is_pinned")
    
    // Tags table
    private let tags = Table("tags")
    private let colTagId = SQLite.Expression<String>("id")
    private let colTagName = SQLite.Expression<String>("name")
    private let colTagColor = SQLite.Expression<String?>("color")
    private let colTagCreatedAt = SQLite.Expression<Double>("created_at")
    
    // Note-Tag junction table
    private let noteTags = Table("note_tags")
    private let colNoteId = SQLite.Expression<String>("note_id")
    private let colTagRefId = SQLite.Expression<String>("tag_id")
    
    // Note links table
    private let noteLinks = Table("note_links")
    private let colLinkId = SQLite.Expression<String>("id")
    private let colSourceNoteId = SQLite.Expression<String>("source_note_id")
    private let colTargetNoteId = SQLite.Expression<String?>("target_note_id")
    private let colTargetTitle = SQLite.Expression<String>("target_title")
    private let colLinkType = SQLite.Expression<String>("link_type")
    private let colConfidence = SQLite.Expression<Double>("confidence")
    private let colLinkCreatedAt = SQLite.Expression<Double>("link_created_at")
    
    // MARK: - Initialization
    
    private init() {
        setupDatabase()
    }
    
    /// Initialize with custom database path (for testing)
    init(dbPath: String) {
        setupDatabase(at: dbPath)
    }
    
    private func setupDatabase(at path: String? = nil) {
        do {
            let dbPath = path ?? getDefaultDatabasePath()
            db = try Connection(dbPath)
            try createTables()
            print("Database initialized at: \(dbPath)")
        } catch {
            print("Database setup error: \(error)")
        }
    }
    
    private func getDefaultDatabasePath() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let noteForgeDir = appSupport.appendingPathComponent("NoteForge")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: noteForgeDir, withIntermediateDirectories: true)
        
        return noteForgeDir.appendingPathComponent("noteforge.sqlite3").path
    }
    
    private func createTables() throws {
        // Notes table
        try db?.run(notes.create(ifNotExists: true) { table in
            table.column(colId, primaryKey: true)
            table.column(colTitle)
            table.column(colContent)
            table.column(colAiSummary)
            table.column(colCreatedAt)
            table.column(colModifiedAt)
            table.column(colSource)
            table.column(colFolderPath)
            table.column(colIsArchived, defaultValue: false)
            table.column(colIsPinned, defaultValue: false)
        })
        
        // Tags table
        try db?.run(tags.create(ifNotExists: true) { table in
            table.column(colTagId, primaryKey: true)
            table.column(colTagName, unique: true)
            table.column(colTagColor)
            table.column(colTagCreatedAt)
        })
        
        // Note-Tag junction table
        try db?.run(noteTags.create(ifNotExists: true) { table in
            table.column(colNoteId)
            table.column(colTagRefId)
            table.primaryKey(colNoteId, colTagRefId)
            table.foreignKey(colNoteId, references: notes, colId, delete: .cascade)
            table.foreignKey(colTagRefId, references: tags, colTagId, delete: .cascade)
        })
        
        // Note links table
        try db?.run(noteLinks.create(ifNotExists: true) { table in
            table.column(colLinkId, primaryKey: true)
            table.column(colSourceNoteId)
            table.column(colTargetNoteId)
            table.column(colTargetTitle)
            table.column(colLinkType)
            table.column(colConfidence)
            table.column(colLinkCreatedAt)
            table.foreignKey(colSourceNoteId, references: notes, colId, delete: .cascade)
        })
        
        // Create indexes for faster queries
        try db?.run(notes.createIndex(colModifiedAt, ifNotExists: true))
        try db?.run(notes.createIndex(colIsArchived, ifNotExists: true))
        try db?.run(notes.createIndex(colIsPinned, ifNotExists: true))
        try db?.run(noteTags.createIndex(colNoteId, ifNotExists: true))
        try db?.run(noteTags.createIndex(colTagRefId, ifNotExists: true))
    }
    
    // MARK: - CRUD Operations
    
    /// Fetch all notes from database
    func fetchAllNotes() -> [Note] {
        var result: [Note] = []
        do {
            guard let db = db else { return [] }
            for row in try db.prepare(notes.order(colModifiedAt.desc)) {
                let note = noteFromRow(row)
                result.append(note)
            }
        } catch {
            print("Fetch error: \(error)")
        }
        return result
    }
    
    /// Fetch a single note by ID
    func fetchNote(id: UUID) -> Note? {
        do {
            guard let db = db else { return nil }
            let query = notes.filter(colId == id.uuidString)
            if let row = try db.pluck(query) {
                return noteFromRow(row)
            }
        } catch {
            print("Fetch note error: \(error)")
        }
        return nil
    }
    
    /// Fetch notes by tag
    func fetchNotes(withTag tagName: String) -> [Note] {
        var result: [Note] = []
        do {
            guard let db = db else { return [] }
            
            let query = notes
                .join(noteTags, on: colId == colNoteId)
                .join(tags, on: colTagRefId == colTagId)
                .filter(colTagName == tagName)
                .order(colModifiedAt.desc)
            
            for row in try db.prepare(query) {
                let note = noteFromRow(row)
                result.append(note)
            }
        } catch {
            print("Fetch notes by tag error: \(error)")
        }
        return result
    }
    
    /// Fetch notes modified after a date
    func fetchNotes(modifiedAfter date: Date) -> [Note] {
        var result: [Note] = []
        do {
            guard let db = db else { return [] }
            let timestamp = date.timeIntervalSince1970
            for row in try db.prepare(notes.filter(colModifiedAt > timestamp).order(colModifiedAt.desc)) {
                let note = noteFromRow(row)
                result.append(note)
            }
        } catch {
            print("Fetch notes after date error: \(error)")
        }
        return result
    }
    
    /// Insert a new note
    func insertNote(_ note: Note) {
        do {
            try db?.run(notes.insert(
                colId <- note.id.uuidString,
                colTitle <- note.title,
                colContent <- note.content,
                colAiSummary <- note.aiSummary,
                colCreatedAt <- note.createdAt.timeIntervalSince1970,
                colModifiedAt <- note.modifiedAt.timeIntervalSince1970,
                colSource <- note.source.rawValue,
                colFolderPath <- note.folderPath,
                colIsArchived <- note.isArchived,
                colIsPinned <- note.isPinned
            ))
            
            // Insert tags
            for tag in note.tags {
                ensureTagExists(name: tag)
                addTagToNote(noteId: note.id, tagName: tag)
            }
            
            // Insert links
            for link in note.links {
                insertNoteLink(link, sourceNoteId: note.id)
            }
            
        } catch {
            print("Insert error: \(error)")
        }
    }
    
    /// Update an existing note
    func updateNote(_ note: Note) {
        let target = notes.filter(colId == note.id.uuidString)
        do {
            try db?.run(target.update(
                colTitle <- note.title,
                colContent <- note.content,
                colAiSummary <- note.aiSummary,
                colModifiedAt <- note.modifiedAt.timeIntervalSince1970,
                colSource <- note.source.rawValue,
                colFolderPath <- note.folderPath,
                colIsArchived <- note.isArchived,
                colIsPinned <- note.isPinned
            ))
            
            // Update tags - remove all and re-add
            removeAllTagsFromNote(noteId: note.id)
            for tag in note.tags {
                ensureTagExists(name: tag)
                addTagToNote(noteId: note.id, tagName: tag)
            }
            
            // Update links - remove all and re-add
            removeAllLinksFromNote(noteId: note.id)
            for link in note.links {
                insertNoteLink(link, sourceNoteId: note.id)
            }
            
        } catch {
            print("Update error: \(error)")
        }
    }
    
    /// Delete a note
    func deleteNote(id noteId: UUID) {
        let target = notes.filter(colId == noteId.uuidString)
        do {
            try db?.run(target.delete())
            // Tags and links are cascade deleted due to foreign key constraints
        } catch {
            print("Delete error: \(error)")
        }
    }
    
    // MARK: - Tag Management
    
    /// Get all tags with note counts
    func fetchAllTags() -> [Tag] {
        var result: [Tag] = []
        do {
            guard let db = db else { return [] }
            
            // Query tags with note counts
            let query = """
                SELECT t.id, t.name, t.color, t.created_at, COUNT(nt.note_id) as note_count
                FROM tags t
                LEFT JOIN note_tags nt ON t.id = nt.tag_id
                GROUP BY t.id
                ORDER BY note_count DESC, t.name ASC
            """
            
            for row in try db.prepare(query) {
                if let idString = row[0] as? String,
                   let id = UUID(uuidString: idString),
                   let name = row[1] as? String,
                   let createdAt = row[3] as? Double {
                    let noteCount = (row[4] as? Int64) ?? 0
                    let tag = Tag(
                        id: id,
                        name: name,
                        color: row[2] as? String,
                        createdAt: Date(timeIntervalSince1970: createdAt),
                        noteCount: Int(noteCount)
                    )
                    result.append(tag)
                }
            }
        } catch {
            print("Fetch tags error: \(error)")
        }
        return result
    }
    
    /// Create a new tag
    func createTag(name: String, color: String? = nil) -> Tag? {
        let tag = Tag(name: name, color: color)
        do {
            try db?.run(tags.insert(
                colTagId <- tag.id.uuidString,
                colTagName <- tag.name,
                colTagColor <- tag.color,
                colTagCreatedAt <- tag.createdAt.timeIntervalSince1970
            ))
            return tag
        } catch {
            print("Create tag error: \(error)")
            return nil
        }
    }
    
    /// Delete a tag
    func deleteTag(id tagId: UUID) {
        let target = tags.filter(colTagId == tagId.uuidString)
        do {
            try db?.run(target.delete())
        } catch {
            print("Delete tag error: \(error)")
        }
    }
    
    /// Ensure a tag exists, create if not
    private func ensureTagExists(name: String) {
        do {
            let query = tags.filter(colTagName == name)
            if try db?.pluck(query) == nil {
                _ = createTag(name: name)
            }
        } catch {
            print("Ensure tag exists error: \(error)")
        }
    }
    
    /// Add a tag to a note
    private func addTagToNote(noteId: UUID, tagName: String) {
        do {
            guard let db = db else { return }
            
            // Get tag ID
            let tagQuery = tags.filter(colTagName == tagName)
            guard let tagRow = try db.pluck(tagQuery) else { return }
            let tagIdString = tagRow[colTagId]
            
            // Insert junction
            try db.run(noteTags.insert(or: .ignore,
                colNoteId <- noteId.uuidString,
                colTagRefId <- tagIdString
            ))
        } catch {
            print("Add tag to note error: \(error)")
        }
    }
    
    /// Remove all tags from a note
    private func removeAllTagsFromNote(noteId: UUID) {
        let target = noteTags.filter(colNoteId == noteId.uuidString)
        do {
            try db?.run(target.delete())
        } catch {
            print("Remove tags from note error: \(error)")
        }
    }
    
    // MARK: - Link Management
    
    /// Insert a note link
    private func insertNoteLink(_ link: NoteLink, sourceNoteId: UUID) {
        do {
            try db?.run(noteLinks.insert(
                colLinkId <- link.id.uuidString,
                colSourceNoteId <- sourceNoteId.uuidString,
                colTargetNoteId <- link.targetNoteId?.uuidString,
                colTargetTitle <- link.targetTitle,
                colLinkType <- link.linkType.rawValue,
                colConfidence <- link.confidence,
                colLinkCreatedAt <- link.createdAt.timeIntervalSince1970
            ))
        } catch {
            print("Insert note link error: \(error)")
        }
    }
    
    /// Remove all links from a note
    private func removeAllLinksFromNote(noteId: UUID) {
        let target = noteLinks.filter(colSourceNoteId == noteId.uuidString)
        do {
            try db?.run(target.delete())
        } catch {
            print("Remove links from note error: \(error)")
        }
    }
    
    /// Get backlinks (notes linking to a specific note)
    func fetchBacklinks(for noteId: UUID) -> [NoteLink] {
        var result: [NoteLink] = []
        do {
            guard let db = db else { return [] }
            
            let query = noteLinks.filter(colTargetNoteId == noteId.uuidString)
            for row in try db.prepare(query) {
                let link = linkFromRow(row)
                result.append(link)
            }
        } catch {
            print("Fetch backlinks error: \(error)")
        }
        return result
    }
    
    // MARK: - Helper Methods
    
    private func noteFromRow(_ row: Row) -> Note {
        let noteId = UUID(uuidString: row[colId]) ?? UUID()
        
        // Fetch tags for this note
        let noteTagQuery = noteTags.filter(colNoteId == row[colId])
        var noteTagsList: [String] = []
        do {
            if let db = db {
                for tagRow in try db.prepare(noteTagQuery) {
                    let tagIdRef = tagRow[colTagRefId]
                    if let tagRow = try db.pluck(tags.filter(colTagId == tagIdRef)) {
                        noteTagsList.append(tagRow[colTagName])
                    }
                }
            }
        } catch {
            print("Fetch note tags error: \(error)")
        }
        
        // Fetch links for this note
        let linkQuery = noteLinks.filter(colSourceNoteId == row[colId])
        var noteLinksList: [NoteLink] = []
        do {
            if let db = db {
                for linkRow in try db.prepare(linkQuery) {
                    noteLinksList.append(linkFromRow(linkRow))
                }
            }
        } catch {
            print("Fetch note links error: \(error)")
        }
        
        return Note(
            id: noteId,
            title: row[colTitle],
            content: row[colContent],
            aiSummary: row[colAiSummary],
            createdAt: Date(timeIntervalSince1970: row[colCreatedAt]),
            modifiedAt: Date(timeIntervalSince1970: row[colModifiedAt]),
            source: NoteSource(rawValue: row[colSource]) ?? .manual,
            tags: noteTagsList,
            links: noteLinksList,
            folderPath: row[colFolderPath],
            isArchived: row[colIsArchived],
            isPinned: row[colIsPinned]
        )
    }
    
    private func linkFromRow(_ row: Row) -> NoteLink {
        NoteLink(
            sourceNoteId: UUID(uuidString: row[colSourceNoteId]) ?? UUID(),
            targetNoteId: row[colTargetNoteId].flatMap { UUID(uuidString: $0) },
            targetTitle: row[colTargetTitle],
            linkType: LinkType(rawValue: row[colLinkType]) ?? .wiki,
            confidence: row[colConfidence],
            createdAt: Date(timeIntervalSince1970: row[colLinkCreatedAt])
        )
    }
    
    // MARK: - Database Maintenance
    
    /// Get database file size
    func getDatabaseSize() -> Int64 {
        do {
            let path = getDefaultDatabasePath()
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            return attrs[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    /// Vacuum database to reclaim space
    func vacuumDatabase() {
        try? db?.execute("VACUUM")
    }
}
