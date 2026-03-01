import Foundation
import Combine

// MARK: - NoteStore

/// NoteStore combines FileStore (markdown files) and DatabaseManager (SQLite)
/// to provide a unified API for note management
@MainActor
final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var tags: [Tag] = []
    @Published var isLoading: Bool = false
    @Published var error: NoteStoreError?
    
    // Storage backends
    private let fileStore: FileStore
    private let dbManager: DatabaseManager
    
    // File watcher for external changes
    private var fileWatcher: FileWatcher?
    private var lastKnownFiles: Set<String> = []
    
    // MARK: - Initialization
    
    /// Initialize with default storage locations
    init() {
        self.fileStore = FileStore.shared
        self.dbManager = DatabaseManager.shared
        loadNotes()
        loadTags()
        setupFileWatcher()
    }
    
    /// Initialize with custom storage (for testing)
    init(fileStore: FileStore, dbManager: DatabaseManager) {
        self.fileStore = fileStore
        self.dbManager = dbManager
        loadNotes()
        loadTags()
    }
    
    // MARK: - Loading
    
    /// Load all notes from database
    func loadNotes() {
        isLoading = true
        notes = dbManager.fetchAllNotes()
        
        // If database is empty, try loading from files
        if notes.isEmpty {
            notes = fileStore.loadAllNotes()
            // Populate database from files
            for note in notes {
                dbManager.insertNote(note)
            }
        }
        
        isLoading = false
    }
    
    /// Load all tags
    func loadTags() {
        tags = dbManager.fetchAllTags()
    }
    
    // MARK: - File Watching
    
    private func setupFileWatcher() {
        // Watch for external file changes
        fileWatcher = FileWatcher(paths: [fileStore.notesDirectory.path])
        
        fileWatcher?.callback = { [weak self] events in
            Task { @MainActor in
                self?.handleFileChanges()
            }
        }
        
        // Initialize last known files
        lastKnownFiles = Set(fileStore.listNoteFiles().map { $0.lastPathComponent })
    }
    
    private func handleFileChanges() {
        let currentFiles = Set(fileStore.listNoteFiles().map { $0.lastPathComponent })
        let added = currentFiles.subtracting(lastKnownFiles)
        let removed = lastKnownFiles.subtracting(currentFiles)
        
        if !added.isEmpty || !removed.isEmpty {
            loadNotes()
        }
        
        lastKnownFiles = currentFiles
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new note
    @discardableResult
    func createNote(
        title: String = "",
        content: String = "",
        source: NoteSource = .manual,
        tags: [String] = [],
        folderPath: String? = nil
    ) -> Note {
        let now = Date()
        let note = Note(
            title: title,
            content: content,
            source: source,
            tags: tags,
            folderPath: folderPath,
            createdAt: now,
            modifiedAt: now
        )
        
        // Save to both file and database
        do {
            try fileStore.saveNote(note)
            dbManager.insertNote(note)
            notes.insert(note, at: 0)
            self.tags = dbManager.fetchAllTags() // Refresh tags
        } catch {
            self.error = .saveFailed(error.localizedDescription)
        }
        
        return note
    }
    
    /// Read a note by ID
    func getNote(id: UUID) -> Note? {
        // First check in-memory
        if let note = notes.first(where: { $0.id == id }) {
            return note
        }
        
        // Fall back to file storage
        return fileStore.loadNote(for: id)
    }
    
    /// Update an existing note
    func updateNote(_ note: Note) {
        var updatedNote = note
        updatedNote.modifiedAt = Date()
        
        // Save to both file and database
        do {
            try fileStore.saveNote(updatedNote)
            dbManager.updateNote(updatedNote)
            
            // Update in-memory array
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = updatedNote
            }
            
            // Re-sort by modified date
            notes.sort { note1, note2 in
                if note1.isPinned != note2.isPinned {
                    return note1.isPinned
                }
                return note1.modifiedAt > note2.modifiedAt
            }
            
            // Refresh tags
            self.tags = dbManager.fetchAllTags()
            
        } catch {
            self.error = .saveFailed(error.localizedDescription)
        }
    }
    
    /// Update note title
    func updateNote(id: UUID, title: String) {
        guard var note = getNote(id: id) else { return }
        note.title = title
        updateNote(note)
    }
    
    /// Update note content
    func updateNote(id: UUID, content: String) {
        guard var note = getNote(id: id) else { return }
        note.content = content
        updateNote(note)
    }
    
    /// Delete a note
    func deleteNote(id: UUID) {
        do {
            try fileStore.deleteNoteFile(for: id)
            dbManager.deleteNote(id: id)
            notes.removeAll { $0.id == id }
            self.tags = dbManager.fetchAllTags() // Refresh tags
        } catch {
            self.error = .deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Tag Management
    
    /// Add a tag to a note
    func addTag(_ tagName: String, to noteId: UUID) {
        guard var note = getNote(id: noteId) else { return }
        
        if !note.tags.contains(tagName) {
            note.tags.append(tagName)
            updateNote(note)
        }
    }
    
    /// Remove a tag from a note
    func removeTag(_ tagName: String, from noteId: UUID) {
        guard var note = getNote(id: noteId) else { return }
        
        note.tags.removeAll { $0 == tagName }
        updateNote(note)
    }
    
    /// Rename a tag across all notes
    func renameTag(from oldName: String, to newName: String) {
        // Update all notes with this tag
        for note in notes where note.tags.contains(oldName) {
            var updatedNote = note
            updatedNote.tags = updatedNote.tags.map { $0 == oldName ? newName : $0 }
            updateNote(updatedNote)
        }
        
        // Refresh tags
        loadTags()
    }
    
    /// Delete a tag from all notes
    func deleteTag(name: String) {
        // Remove tag from all notes
        for note in notes where note.tags.contains(name) {
            var updatedNote = note
            updatedNote.tags.removeAll { $0 == name }
            updateNote(updatedNote)
        }
        
        // Delete tag from database
        if let tag = tags.first(where: { $0.name == name }) {
            dbManager.deleteTag(id: tag.id)
        }
        
        loadTags()
    }
    
    /// Get notes with a specific tag
    func getNotes(withTag tagName: String) -> [Note] {
        return notes.filter { $0.tags.contains(tagName) }
    }
    
    // MARK: - Link Management
    
    /// Add a link from one note to another
    func addLink(
        from sourceNoteId: UUID,
        to targetNoteId: UUID,
        targetTitle: String,
        type: LinkType = .wiki
    ) {
        guard var sourceNote = getNote(id: sourceNoteId) else { return }
        
        // Check if link already exists
        let linkExists = sourceNote.links.contains { link in
            link.targetNoteId == targetNoteId || link.targetTitle == targetTitle
        }
        
        if !linkExists {
            let newLink = NoteLink(
                sourceNoteId: sourceNoteId,
                targetNoteId: targetNoteId,
                targetTitle: targetTitle,
                linkType: type
            )
            sourceNote.links.append(newLink)
            updateNote(sourceNote)
        }
    }
    
    /// Remove a link from a note
    func removeLink(from sourceNoteId: UUID, to targetNoteId: UUID) {
        guard var sourceNote = getNote(id: sourceNoteId) else { return }
        
        sourceNote.links.removeAll { $0.targetNoteId == targetNoteId }
        updateNote(sourceNote)
    }
    
    /// Get backlinks for a note (notes that link to this note)
    func getBacklinks(for noteId: UUID) -> [Note] {
        return notes.filter { note in
            note.links.contains { $0.targetNoteId == noteId }
        }
    }
    
    /// Get all related notes for a note
    func getRelatedNotes(for noteId: UUID) -> [Note] {
        guard let note = getNote(id: noteId) else { return [] }
        
        var related: [Note] = []
        
        // Forward links
        for link in note.links {
            if let targetId = link.targetNoteId,
               let targetNote = getNote(id: targetId) {
                related.append(targetNote)
            }
        }
        
        // Backlinks
        let backlinks = getBacklinks(for: noteId)
        related.append(contentsOf: backlinks)
        
        // Remove duplicates and self
        return related.filter { $0.id != noteId }
    }
    
    // MARK: - Note Operations
    
    /// Archive a note
    func archiveNote(id: UUID) {
        guard var note = getNote(id: id) else { return }
        note.isArchived = true
        updateNote(note)
    }
    
    /// Unarchive a note
    func unarchiveNote(id: UUID) {
        guard var note = getNote(id: id) else { return }
        note.isArchived = false
        updateNote(note)
    }
    
    /// Pin a note
    func pinNote(id: UUID) {
        guard var note = getNote(id: id) else { return }
        note.isPinned = true
        updateNote(note)
    }
    
    /// Unpin a note
    func unpinNote(id: UUID) {
        guard var note = getNote(id: id) else { return }
        note.isPinned = false
        updateNote(note)
    }
    
    /// Toggle pin status
    func togglePin(id: UUID) {
        guard var note = getNote(id: id) else { return }
        note.isPinned.toggle()
        updateNote(note)
    }
    
    // MARK: - Search & Filter
    
    /// Search notes by title or content
    func searchNotes(query: String) -> [Note] {
        let lowercasedQuery = query.lowercased()
        return notes.filter { note in
            note.title.lowercased().contains(lowercasedQuery) ||
            note.content.lowercased().contains(lowercasedQuery) ||
            note.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    /// Get recent notes
    func getRecentNotes(limit: Int = 10) -> [Note] {
        return Array(notes.prefix(limit))
    }
    
    /// Get pinned notes
    func getPinnedNotes() -> [Note] {
        return notes.filter { $0.isPinned }
    }
    
    /// Get archived notes
    func getArchivedNotes() -> [Note] {
        return notes.filter { $0.isArchived }
    }
    
    /// Get notes from a specific source
    func getNotes(from source: NoteSource) -> [Note] {
        return notes.filter { $0.source == source }
    }
    
    /// Get notes in a specific folder
    func getNotes(inFolder folderPath: String) -> [Note] {
        return notes.filter { $0.folderPath == folderPath }
    }
    
    // MARK: - Utility
    
    /// Clear error state
    func clearError() {
        error = nil
    }
    
    /// Get total note count
    var noteCount: Int {
        notes.count
    }
    
    /// Get active (non-archived) note count
    var activeNoteCount: Int {
        notes.filter { !$0.isArchived }.count
    }
}

// MARK: - NoteStoreError

enum NoteStoreError: LocalizedError {
    case saveFailed(String)
    case deleteFailed(String)
    case notFound
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save note: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete note: \(message)"
        case .notFound:
            return "Note not found"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
