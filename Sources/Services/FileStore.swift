import Foundation

/// FileStore handles reading/writing notes as markdown files with YAML frontmatter
final class FileStore {
    static let shared = FileStore()
    
    private let fileManager = FileManager.default
    private let notesDirectoryName = "Notes"
    
    private var notesDirectory: URL {
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
    
    private func fileURL(for noteId: UUID) -> URL {
        notesDirectory.appendingPathComponent("\(noteId.uuidString).md")
    }
    
    // MARK: - Read Operations
    
    /// Load note content from markdown file
    func loadNoteContent(for noteId: UUID) -> String? {
        let url = fileURL(for: noteId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
    
    /// Parse markdown file with YAML frontmatter into Note
    func parseMarkdownFile(at url: URL) -> (metadata: NoteMetadata, content: String)? {
        guard let fileContent = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return parseMarkdownContent(fileContent)
    }
    
    /// Parse markdown content with YAML frontmatter
    func parseMarkdownContent(_ content: String) -> (metadata: NoteMetadata, content: String)? {
        // Check for YAML frontmatter delimiter
        guard content.hasPrefix("---") else {
            // No frontmatter, treat entire content as note content
            return (NoteMetadata(), content)
        }
        
        // Find closing delimiter
        guard let endRange = content.range(of: "---", options: [], range: content.index(content.startIndex, offsetBy: 3)..<content.endIndex),
              endRange.lowerBound != content.startIndex else {
            return (NoteMetadata(), content)
        }
        
        let yamlString = String(content[content.startIndex..<endRange.lowerBound])
        let noteContent = String(content[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse YAML
        let metadata = parseYAML(yamlString)
        return (metadata, noteContent)
    }
    
    // MARK: - Write Operations
    
    /// Save note content to markdown file with YAML frontmatter
    func saveNoteContent(_ note: Note) throws {
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
        lines.append("created_at: \(formatter.string(from: note.createdAt))")
        lines.append("updated_at: \(formatter.string(from: note.updatedAt))")
        
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
                var linkLine = "  - title: \(escapeYAML(link.targetTitle))"
                if let targetId = link.targetNoteId {
                    linkLine += "\n    id: \(targetId.uuidString)"
                }
                linkLine += "\n    type: \(link.linkType.rawValue)"
                lines.append(linkLine)
            }
        }
        
        // Source
        lines.append("source: \(note.source.rawValue)")
        
        // Flags
        if note.isArchived {
            lines.append("archived: true")
        }
        if note.isPinned {
            lines.append("pinned: true")
        }
        
        lines.append("---")
        lines.append("")
        
        // Note content
        lines.append(note.content)
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - YAML Parsing
    
    private struct NoteMetadata {
        var id: UUID?
        var title: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var tags: [String] = []
        var links: [NoteLink] = []
        var source: NoteSource = .manual
        var isArchived: Bool = false
        var isPinned: Bool = false
    }
    
    private func parseYAML(_ yaml: String) -> NoteMetadata {
        var metadata = NoteMetadata()
        let lines = yaml.components(separatedBy: .newlines).filter { !$0.hasPrefix("---") }
        
        var currentKey = ""
        var inTags = false
        var inLinks = false
        
        let dateFormatter = ISO8601DateFormatter()
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for list items
            if trimmed.hasPrefix("- ") {
                if inTags {
                    let tag = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if !tag.isEmpty {
                        metadata.tags.append(tag)
                    }
                } else if inLinks {
                    // Parse link item
                    let linkContent = String(trimmed.dropFirst(2))
                    var link = NoteLink(targetTitle: "")
                    
                    // Simple parsing - look for title:
                    if linkContent.contains("title:") {
                        if let titleRange = linkContent.range(of: "title:") {
                            let titleValue = String(linkContent[titleRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                            link = NoteLink(targetTitle: unescapeYAML(titleValue))
                        }
                        if let idRange = linkContent.range(of: "id:") {
                            let idValue = String(linkContent[idRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                            if let uuid = UUID(uuidString: idValue) {
                                link.targetNoteId = uuid
                            }
                        }
                        if let typeRange = linkContent.range(of: "type:") {
                            let typeValue = String(linkContent[typeRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                            link.linkType = LinkType(rawValue: typeValue) ?? .wiki
                        }
                    } else {
                        link = NoteLink(targetTitle: unescapeYAML(linkContent))
                    }
                    metadata.links.append(link)
                }
                continue
            }
            
            // Reset flags when we hit a new key
            inTags = false
            inLinks = false
            
            // Parse key-value pairs
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "id":
                    metadata.id = UUID(uuidString: value)
                case "title":
                    metadata.title = unescapeYAML(value)
                case "created_at":
                    metadata.createdAt = dateFormatter.date(from: value) ?? Date()
                case "updated_at":
                    metadata.updatedAt = dateFormatter.date(from: value) ?? Date()
                case "tags":
                    inTags = true
                case "links":
                    inLinks = true
                case "source":
                    metadata.source = NoteSource(rawValue: value) ?? .manual
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
}
