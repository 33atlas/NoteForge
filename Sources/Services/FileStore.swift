import Foundation

// MARK: - FileStore

/// FileStore handles reading/writing notes as markdown files with YAML frontmatter
final class FileStore {
    static let shared = FileStore()
    
    private let fileManager = FileManager.default
    private let notesDirectoryName = "Notes"
    
    /// Notes directory path - configurable for testing
    var notesDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let noteForgeDir = appSupport.appendingPathComponent("NoteForge")
        return noteForgeDir.appendingPathComponent(notesDirectoryName)
    }
    
    private init() {
        createNotesDirectoryIfNeeded()
    }
    
    // MARK: - Directory Management
    
    private func createNotesDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: notesDirectory.path) {
            try? fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Create notes directory at custom path (for testing)
    func createNotesDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    private func fileURL(for noteId: UUID) -> URL {
        notesDirectory.appendingPathComponent("\(noteId.uuidString).md")
    }
    
    /// Get file URL for a specific note ID in a custom directory
    func fileURL(for noteId: UUID, in directory: URL) -> URL {
        directory.appendingPathComponent("\(noteId.uuidString).md")
    }
    
    // MARK: - Read Operations
    
    /// Load complete Note from markdown file
    func loadNote(for noteId: UUID) -> Note? {
        let url = fileURL(for: noteId)
        return parseMarkdownFile(at: url)
    }
    
    /// Load note content only (without metadata)
    func loadNoteContent(for noteId: UUID) -> String? {
        let url = fileURL(for: noteId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
    
    /// Parse markdown file with YAML frontmatter into Note
    func parseMarkdownFile(at url: URL) -> Note? {
        guard let fileContent = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        let (metadata, content) = parseMarkdownContent(fileContent)
        
        return Note(
            id: metadata.id ?? UUID(),
            title: metadata.title.isEmpty ? extractTitleFromContent(content) : metadata.title,
            content: content,
            aiSummary: metadata.aiSummary,
            createdAt: metadata.createdAt,
            modifiedAt: metadata.modifiedAt,
            source: metadata.source,
            tags: metadata.tags,
            links: metadata.links,
            folderPath: metadata.folderPath,
            isArchived: metadata.isArchived,
            isPinned: metadata.isPinned
        )
    }
    
    /// Parse markdown content with YAML frontmatter
    func parseMarkdownContent(_ content: String) -> (metadata: NoteFileMetadata, content: String) {
        // Check for YAML frontmatter delimiter
        guard content.hasPrefix("---") else {
            // No frontmatter, treat entire content as note content
            return (NoteFileMetadata(), content)
        }
        
        // Find closing delimiter
        guard let endRange = content.range(of: "---", options: [], range: content.index(content.startIndex, offsetBy: 3)..<content.endIndex),
              endRange.lowerBound != content.startIndex else {
            return (NoteFileMetadata(), content)
        }
        
        let yamlString = String(content[content.startIndex..<endRange.lowerBound])
        let noteContent = String(content[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse YAML
        let metadata = parseYAML(yamlString)
        return (metadata, noteContent)
    }
    
    /// Extract title from first markdown heading if no title in frontmatter
    private func extractTitleFromContent(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        // Return first line if no heading found
        if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return String(firstLine.prefix(50)).trimmingCharacters(in: .whitespaces)
        }
        return "Untitled"
    }
    
    // MARK: - Write Operations
    
    /// Save note to markdown file with YAML frontmatter
    func saveNote(_ note: Note) throws {
        let url = fileURL(for: note.id)
        let markdown = buildMarkdownContent(note: note)
        try markdown.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Delete markdown file for note
    func deleteNoteFile(for noteId: UUID) throws {
        let url = fileURL(for: noteId)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    /// Build markdown content with YAML frontmatter
    private func buildMarkdownContent(note: Note) -> String {
        var lines: [String] = []
        
        // YAML Frontmatter
        lines.append("---")
        lines.append("id: \(note.id.uuidString)")
        lines.append("title: \(escapeYAML(note.title))")
        
        // Dates
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        lines.append("created_at: \(formatter.string(from: note.createdAt))")
        lines.append("modified_at: \(formatter.string(from: note.modifiedAt))")
        
        // AI Summary
        if let summary = note.aiSummary {
            lines.append("ai_summary: \(escapeYAML(summary))")
        }
        
        // Source
        lines.append("source: \(note.source.rawValue)")
        
        // Tags
        if !note.tags.isEmpty {
            lines.append("tags:")
            for tag in note.tags {
                lines.append("  - \(escapeYAML(tag))")
            }
        }
        
        // Links
        if !note.links.isEmpty {
            lines.append("links:")
            for link in note.links {
                lines.append("  - title: \(escapeYAML(link.targetTitle))")
                if let targetId = link.targetNoteId {
                    lines.append("    id: \(targetId.uuidString)")
                }
                lines.append("    type: \(link.linkType.rawValue)")
                lines.append("    confidence: \(link.confidence)")
            }
        }
        
        // Folder
        if let folder = note.folderPath {
            lines.append("folder: \(escapeYAML(folder))")
        }
        
        // Flags
        if note.isArchived {
            lines.append("archived: true")
        }
        if note.isPinned {
            lines.append("pinned: true")
        }
        
        lines.append("---")
        lines.append("")
        
        // Note content - prepend title as heading if not present
        var content = note.content
        if !note.title.isEmpty && !content.hasPrefix("# ") {
            content = "# \(note.title)\n\n\(content)"
        }
        lines.append(content)
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - YAML Parsing
    
    private struct NoteFileMetadata {
        var id: UUID?
        var title: String = ""
        var aiSummary: String?
        var createdAt: Date = Date()
        var modifiedAt: Date = Date()
        var tags: [String] = []
        var links: [NoteLink] = []
        var source: NoteSource = .manual
        var folderPath: String?
        var isArchived: Bool = false
        var isPinned: Bool = false
    }
    
    private func parseYAML(_ yaml: String) -> NoteFileMetadata {
        var metadata = NoteFileMetadata()
        let lines = yaml.components(separatedBy: .newlines).filter { !$0.hasPrefix("---") }
        
        var currentKey = ""
        var inTags = false
        var inLinks = false
        var currentLink: NoteLink?
        var sourceNoteId = UUID() // Temporary, will be overridden
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for list items
            if trimmed.hasPrefix("- ") {
                let listContent = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                
                if inTags {
                    if !listContent.isEmpty {
                        metadata.tags.append(unescapeYAML(listContent))
                    }
                } else if inLinks {
                    // Start new link
                    currentLink = NoteLink(
                        sourceNoteId: sourceNoteId,
                        targetTitle: ""
                    )
                    
                    // Parse link properties
                    if listContent.contains("title:") {
                        if let titleRange = listContent.range(of: "title:") {
                            let titleValue = String(listContent[titleRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                            currentLink?.targetTitle = unescapeYAML(titleValue)
                        }
                    }
                }
                continue
            }
            
            // Check for indented link properties
            if trimmed.hasPrefix("  - ") || trimmed.hasPrefix("    ") {
                let indentContent = trimmed.trimmingCharacters(in: .whitespaces)
                
                if inLinks, var link = currentLink {
                    if indentContent.hasPrefix("title:") {
                        let value = String(indentContent.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        link.targetTitle = unescapeYAML(value)
                        currentLink = link
                    } else if indentContent.hasPrefix("id:") {
                        let value = String(indentContent.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        if let uuid = UUID(uuidString: value) {
                            link.targetNoteId = uuid
                        }
                        currentLink = link
                    } else if indentContent.hasPrefix("type:") {
                        let value = String(indentContent.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        link.linkType = LinkType(rawValue: value) ?? .wiki
                        currentLink = link
                    } else if indentContent.hasPrefix("confidence:") {
                        let value = String(indentContent.dropFirst(11)).trimmingCharacters(in: .whitespaces)
                        link.confidence = Double(value) ?? 1.0
                        currentLink = link
                    }
                    
                    // Add completed link to metadata
                    if !link.targetTitle.isEmpty || link.targetNoteId != nil {
                        if !metadata.links.contains(where: { $0.targetNoteId == link.targetNoteId && $0.targetTitle == link.targetTitle }) {
                            metadata.links.append(link)
                        }
                    }
                }
                continue
            }
            
            // Reset flags when we hit a new key
            inTags = false
            inLinks = false
            
            // Save any pending link
            if let link = currentLink, !link.targetTitle.isEmpty || link.targetNoteId != nil {
                if !metadata.links.contains(where: { $0.targetNoteId == link.targetNoteId }) {
                    metadata.links.append(link)
                }
            }
            currentLink = nil
            
            // Parse key-value pairs
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "id":
                    if let uuid = UUID(uuidString: value) {
                        metadata.id = uuid
                        sourceNoteId = uuid
                    }
                case "title":
                    metadata.title = unescapeYAML(value)
                case "ai_summary":
                    metadata.aiSummary = unescapeYAML(value)
                case "created_at":
                    metadata.createdAt = dateFormatter.date(from: value) ?? Date()
                case "modified_at":
                    metadata.modifiedAt = dateFormatter.date(from: value) ?? Date()
                case "tags":
                    inTags = true
                case "links":
                    inLinks = true
                case "source":
                    metadata.source = NoteSource(rawValue: value) ?? .manual
                case "folder":
                    metadata.folderPath = unescapeYAML(value)
                case "archived":
                    metadata.isArchived = value.lowercased() == "true"
                case "pinned":
                    metadata.isPinned = value.lowercased() == "true"
                default:
                    break
                }
            }
        }
        
        return metadata
    }
    
    // MARK: - YAML Escaping
    
    private func escapeYAML(_ string: String) -> String {
        // Check if string needs quoting
        let needsQuoting = string.contains(":") || 
                          string.contains("#") || 
                          string.contains("[") || 
                          string.contains("]") ||
                          string.contains("{") ||
                          string.contains("}") ||
                          string.contains(",") ||
                          string.contains("&") ||
                          string.contains("*") ||
                          string.contains("!") ||
                          string.contains("|") ||
                          string.contains(">") ||
                          string.contains("'") ||
                          string.contains("\"") ||
                          string.contains("%") ||
                          string.contains("@") ||
                          string.hasPrefix(" ") ||
                          string.hasSuffix(" ")
        
        if needsQuoting {
            let escaped = string.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return string
    }
    
    private func unescapeYAML(_ string: String) -> String {
        var result = string
        if (result.hasPrefix("\"") && result.hasSuffix("\"")) ||
           (result.hasPrefix("'") && result.hasSuffix("'")) {
            result = String(result.dropFirst().dropLast())
        }
        return result.replacingOccurrences(of: "\\\"", with: "\"")
    }
    
    // MARK: - Directory Operations
    
    /// List all note files in the notes directory
    func listNoteFiles() -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: notesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return contents
            .filter { $0.pathExtension == "md" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return date1 > date2
            }
    }
    
    /// Load all notes from the notes directory
    func loadAllNotes() -> [Note] {
        let files = listNoteFiles()
        return files.compactMap { parseMarkdownFile(at: $0) }
    }
    
    /// Check if a note file exists
    func noteExists(id: UUID) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: id).path)
    }
}
