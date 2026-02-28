import Foundation
import Combine

@MainActor
class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var tags: [Tag] = []
    @Published var selectedNote: Note?
    @Published var searchText: String = ""
    @Published var showQuickCapture: Bool = false
    @Published var selectedFolder: String? = nil
    @Published var isLoading: Bool = false
    
    private let fileManager = FileManager.default
    private var notesDirectory: URL
    private var databasePath: URL
    
    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("NoteForge", isDirectory: true)
        
        notesDirectory = appDirectory.appendingPathComponent("Notes", isDirectory: true)
        databasePath = appDirectory.appendingPathComponent("noteforge.sqlite")
        
        createDirectoriesIfNeeded()
        loadNotes()
        loadTags()
    }
    
    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - CRUD Operations
    
    func createNote(title: String = "", content: String = "", source: CaptureSource = .manual) -> Note {
        let note = Note(
            title: title.isEmpty ? "Untitled Note" : title,
            content: content,
            source: source
        )
        notes.insert(note, at: 0)
        saveNote(note)
        selectedNote = note
        return note
    }
    
    func updateNote(_ note: Note) {
        var updatedNote = note
        updatedNote.modifiedAt = Date()
        
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = updatedNote
        }
        
        if selectedNote?.id == note.id {
            selectedNote = updatedNote
        }
        
        saveNote(updatedNote)
    }
    
    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes.remove(at: index)
        }
        
        deleteNoteFile(note)
        
        if selectedNote?.id == note.id {
            selectedNote = notes.first
        }
    }
    
    // MARK: - File Operations
    
    private func saveNote(_ note: Note) {
        let fileName = "\(note.id.uuidString).md"
        let filePath = notesDirectory.appendingPathComponent(fileName)
        
        var content = note.content
        if !note.tags.isEmpty {
            content = "---\ntags: \(note.tags.joined(separator: ", "))\n---\n\n" + content
        }
        
        try? content.write(to: filePath, atomically: true, encoding: .utf8)
    }
    
    private func deleteNoteFile(_ note: Note) {
        let fileName = "\(note.id.uuidString).md"
        let filePath = notesDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: filePath)
    }
    
    private func loadNotes() {
        guard let files = try? fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        var loadedNotes: [Note] = []
        
        for file in files where file.pathExtension == "md" {
            if let content = try? String(contentsOf: file, encoding: .utf8) {
                let idString = file.deletingPathExtension().lastPathComponent
                if let id = UUID(uuidString: idString) {
                    var title = "Untitled Note"
                    var noteContent = content
                    var tags: [String] = []
                    
                    // Parse frontmatter if present
                    if content.hasPrefix("---") {
                        let parts = content.components(separatedBy: "---")
                        if parts.count >= 3 {
                            let frontmatter = parts[1]
                            noteContent = parts.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Parse tags
                            if let tagLine = frontmatter.components(separatedBy: .newlines).first(where: { $0.hasPrefix("tags:") }) {
                                let tagString = tagLine.replacingOccurrences(of: "tags:", with: "").trimmingCharacters(in: .whitespaces)
                                tags = tagString.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
                            }
                        }
                    }
                    
                    // Extract title from first line
                    let lines = noteContent.components(separatedBy: .newlines)
                    if let firstLine = lines.first, !firstLine.isEmpty {
                        if firstLine.hasPrefix("# ") {
                            title = String(firstLine.dropFirst(2))
                        } else {
                            title = String(firstLine.prefix(50))
                        }
                    }
                    
                    let note = Note(
                        id: id,
                        title: title,
                        content: noteContent,
                        tags: tags,
                        createdAt: (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date(),
                        modifiedAt: (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                    )
                    loadedNotes.append(note)
                }
            }
        }
        
        notes = loadedNotes.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    // MARK: - Tags
    
    func addTag(_ tagName: String) {
        let tag = Tag(name: tagName)
        if !tags.contains(where: { $0.name.lowercased() == tagName.lowercased() }) {
            tags.append(tag)
        }
    }
    
    func addTagToNote(_ tagName: String, note: Note) {
        addTag(tagName)
        
        var updatedNote = note
        if !updatedNote.tags.contains(tagName) {
            updatedNote.tags.append(tagName)
            updateNote(updatedNote)
        }
    }
    
    func removeTagFromNote(_ tagName: String, note: Note) {
        var updatedNote = note
        updatedNote.tags.removeAll { $0 == tagName }
        updateNote(updatedNote)
    }
    
    private func loadTags() {
        // Load tags from stored notes
        var allTags: Set<String> = []
        for note in notes {
            for tag in note.tags {
                allTags.insert(tag)
            }
        }
        tags = allTags.sorted().map { Tag(name: $0) }
    }
    
    // MARK: - Search
    
    var filteredNotes: [Note] {
        var result = notes
        
        // Filter by folder
        if let folder = selectedFolder {
            result = result.filter { $0.folderPath == folder }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { note in
                note.title.lowercased().contains(query) ||
                note.content.lowercased().contains(query) ||
                note.tags.contains { $0.lowercased().contains(query) }
            }
        }
        
        return result
    }
    
    var recentNotes: [Note] {
        Array(notes.prefix(10))
    }
    
    var todayNotes: [Note] {
        let calendar = Calendar.current
        return notes.filter { calendar.isDateInToday($0.createdAt) }
    }
    
    var folders: [String] {
        var folderSet: Set<String> = []
        for note in notes {
            if let folder = note.folderPath {
                folderSet.insert(folder)
            }
        }
        return Array(folderSet).sorted()
    }
    
    // MARK: - Quick Capture
    
    func quickCapture(content: String) {
        _ = createNote(content: content, source: .text)
        showQuickCapture = false
    }
}
