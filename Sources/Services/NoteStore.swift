import Foundation
import Combine

final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var allTags: [String] = []
    @Published var searchQuery: String = ""
    @Published var selectedTag: String?
    
    private let database = DatabaseManager.shared
    private let fileStore = FileStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadNotes()
        loadTags()
        setupSearchBinding()
    }
    
    private func setupSearchBinding() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                if query.isEmpty {
                    self?.loadNotes()
                } else {
                    self?.searchNotes(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load Operations
    
    func loadNotes() {
        if let tag = selectedTag {
            notes = database.fetchNotes(withTag: tag)
        } else {
            notes = database.fetchAllNotes()
        }
    }
    
    func loadTags() {
        allTags = database.fetchAllTags()
    }
    
    // MARK: - Create Operations
    
    /// Create a new note
    func createNote(title: String = "", content: String = "", source: NoteSource = .manual) -> Note {
        var note = Note(
            title: title.isEmpty ? "Untitled" : title,
            content: content,
            source: source
        )
        
        // Save to database
        database.saveNote(note)
        
        // Save markdown file
        try? fileStore.saveNoteContent(note)
        
        // Reload
        loadNotes()
        
        return note
    }
    
    // MARK: - Read Operations
    
    /// Get a specific note by ID
    func getNote(byId id: UUID) -> Note? {
        // First check memory
        if let note = notes.first(where: { $0.id == id }) {
            return note
        }
        // Fallback to database
        return database.fetchNote(byId: id)
    }
    
    /// Get note content from file (for large notes)
    func getNoteContent(for noteId: UUID) -> String? {
        return fileStore.loadNoteContent(for: noteId)
    }
    
    // MARK: - Update Operations
    
    /// Save/update a note
    func saveNote(_ note: Note) {
        var updatedNote = note
        updatedNote.updatedAt = Date()
        
        // Sync links from content
        updatedNote.syncLinksFromContent()
        
        // Update database
        database.saveNote(updatedNote)
        
        // Update markdown file
        try? fileStore.saveNoteContent(updatedNote)
        
        // Update local state
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = updatedNote
        }
        
        // Reload tags (might have new ones)
        loadTags()
    }
    
    /// Update note title
    func updateTitle(_ noteId: UUID, title: String) {
        guard var note = getNote(byId: noteId) else { return }
        note.title = title
        saveNote(note)
    }
    
    /// Update note content
    func updateContent(_ noteId: UUID, content: String) {
        guard var note = getNote(byId: noteId) else { return }
        note.content = content
        saveNote(note)
    }
    
    // MARK: - Delete Operations
    
    /// Delete a note
    func deleteNote(_ note: Note) {
        // Remove from database
        database.deleteNote(note.id)
        
        // Remove markdown file
        try? fileStore.deleteNoteFile(for: note.id)
        
        // Remove from local state
        notes.removeAll { $0.id == note.id }
        
        // Reload tags
        loadTags()
    }
    
    /// Delete note by ID
    func deleteNote(byId id: UUID) {
        if let note = getNote(byId: id) {
            deleteNote(note)
        }
    }
    
    // MARK: - Tag Management
    
    /// Add a tag to a note
    func addTag(_ tag: String, to noteId: UUID) {
        guard var note = getNote(byId: noteId) else { return }
        note.addTag(tag)
        saveNote(note)
        loadTags()
    }
    
    /// Remove a tag from a note
    func removeTag(_ tag: String, from noteId: UUID) {
        guard var note = getNote(byId: noteId) else { return }
        note.removeTag(tag)
        saveNote(note)
        loadTags()
    }
    
    /// Set tags for a note
    func setTags(_ tags: [String], for noteId: UUID) {
        guard var note = getNote(byId: noteId) else { return }
        note.updateTags(tags)
        saveNote(note)
        loadTags()
    }
    
    /// Filter notes by tag
    func filterByTag(_ tag: String?) {
        selectedTag = tag
        loadNotes()
    }
    
    // MARK: - Link Management
    
    /// Add a link from one note to another
    func addLink(from sourceNoteId: UUID, to targetNoteId: UUID, title: String) {
        guard var sourceNote = getNote(byId: sourceNoteId) else { return }
        
        let link = NoteLink(targetNoteId: targetNoteId, targetTitle: title)
        sourceNote.addLink(link)
        saveNote(sourceNote)
    }
    
    /// Remove a link from a note
    func removeLink(from noteId: UUID, targetTitle: String) {
        guard var note = getNote(byId: noteId) else { return }
        note.removeLink(toTargetTitle: targetTitle)
        saveNote(note)
    }
    
    /// Get notes that link to a specific note (backlinks)
    func getBacklinks(for noteId: UUID) -> [Note] {
        return database.fetchNoteslinkingTo(noteId)
    }
    
    /// Get notes linked from a specific note (outlinks)
    func getOutlinks(for noteId: UUID) -> [Note] {
        return database.fetchNotesLinkedFrom(noteId)
    }
    
    // MARK: - Search
    
    /// Search notes by query
    func searchNotes(query: String) {
        notes = database.searchNotes(query: query)
    }
    
    // MARK: - Archive/Pin Operations
    
    /// Archive a note
    func archiveNote(_ noteId: UUID) {
        guard var note = getNote(byId: noteId) else { return }
        note.isArchived = true
        saveNote(note)
    }
    
    /// Unarchive a note
    func unarchiveNote(_ noteId: UUID) {
        guard var note = getNote(byId: noteId) else { return }
        note.isArchived = false
        saveNote(note)
    }
    
    /// Toggle pin status
    func togglePin(_ noteId: UUID) {
        guard var note = getNote(byId: noteId) else { return }
        note.isPinned.toggle()
        saveNote(note)
    }
    
    /// Get archived notes
    func getArchivedNotes() -> [Note] {
        return notes.filter { $0.isArchived }
    }
    
    /// Get pinned notes
    func getPinnedNotes() -> [Note] {
        return notes.filter { $0.isPinned }
    }
    
    // MARK: - Import/Export
    
    /// Import a markdown file
    func importMarkdownFile(at url: URL) -> Note? {
        guard let (metadata, content) = fileStore.parseMarkdownFile(at: url) else {
            return nil
        }
        
        var note: Note
        if let existingId = metadata.id {
            note = Note(
                id: existingId,
                title: metadata.title.isEmpty ? url.deletingPathExtension().lastPathComponent : metadata.title,
                content: content,
                createdAt: metadata.createdAt,
                updatedAt: metadata.updatedAt,
                tags: metadata.tags,
                links: metadata.links,
                source: metadata.source,
                isArchived: metadata.isArchived,
                isPinned: metadata.isPinned
            )
        } else {
            note = Note(
                title: metadata.title.isEmpty ? url.deletingPathExtension().lastPathComponent : metadata.title,
                content: content,
                createdAt: metadata.createdAt,
                updatedAt: metadata.updatedAt,
                tags: metadata.tags,
                links: metadata.links,
                source: metadata.source,
                isArchived: metadata.isArchived,
                isPinned: metadata.isPinned
            )
        }
        
        database.saveNote(note)
        try? fileStore.saveNoteContent(note)
        loadNotes()
        loadTags()
        
        return note
    }
    
    /// Export a note to markdown file
    func exportNote(_ note: Note, to url: URL) throws {
        try fileStore.saveNoteContent(note)
    }
    
    // MARK: - Refresh
    
    /// Refresh all data
    func refresh() {
        loadNotes()
        loadTags()
    }
}
