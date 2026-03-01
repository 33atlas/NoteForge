import Foundation

/// Note model with all fields from PRD
struct Note: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    
    // Extended fields for PKM
    var tags: [String]
    var links: [NoteLink]
    var source: NoteSource
    var isArchived: Bool
    var isPinned: Bool
    
    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        links: [NoteLink] = [],
        source: NoteSource = .manual,
        isArchived: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.links = links
        self.source = source
        self.isArchived = isArchived
        self.isPinned = isPinned
    }
    
    /// Extracts wiki-style links [[note title]] from content
    var extractedLinks: [String] {
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }
    }
}

// MARK: - NoteLink

struct NoteLink: Codable, Equatable, Identifiable {
    var id: UUID
    var targetNoteId: UUID?
    var targetTitle: String
    var linkType: LinkType
    
    init(
        id: UUID = UUID(),
        targetNoteId: UUID? = nil,
        targetTitle: String,
        linkType: LinkType = .wiki
    ) {
        self.id = id
        self.targetNoteId = targetNoteId
        self.targetTitle = targetTitle
        self.linkType = linkType
    }
}

enum LinkType: String, Codable, CaseIterable {
    case wiki = "wiki"
    case markdown = "markdown"
    case tag = "tag"
    case url = "url"
}

// MARK: - NoteSource

enum NoteSource: String, Codable, CaseIterable {
    case manual = "manual"
    case text = "text"
    case voice = "voice"
    case url = "url"
    case screenshot = "screenshot"
    case import_ = "import"
    
    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .text: return "Text"
        case .voice: return "Voice"
        case .url: return "URL"
        case .screenshot: return "Screenshot"
        case .import_: return "Import"
        }
    }
    
    var iconName: String {
        switch self {
        case .manual: return "pencil"
        case .text: return "doc.text"
        case .voice: return "mic"
        case .url: return "link"
        case .screenshot: return "photo"
        case .import_: return "square.and.arrow.down"
        }
    }
}

// MARK: - Tag Management

extension Note {
    mutating func addTag(_ tag: String) {
        let normalizedTag = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTag.isEmpty, !tags.contains(normalizedTag) else { return }
        tags.append(normalizedTag)
    }
    
    mutating func removeTag(_ tag: String) {
        tags.removeAll { $0.lowercased() == tag.lowercased() }
    }
    
    mutating func updateTags(_ newTags: [String]) {
        tags = newTags
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Link Management

extension Note {
    mutating func addLink(_ link: NoteLink) {
        guard !links.contains(where: { $0.targetTitle == link.targetTitle }) else { return }
        links.append(link)
    }
    
    mutating func removeLink(toTargetTitle title: String) {
        links.removeAll { $0.targetTitle.lowercased() == title.lowercased() }
    }
    
    mutating func syncLinksFromContent() {
        // Keep manually added links, add new ones from content
        let contentLinks = extractedLinks
        for linkTitle in contentLinks {
            if !links.contains(where: { $0.targetTitle.lowercased() == linkTitle.lowercased() }) {
                links.append(NoteLink(targetTitle: linkTitle))
            }
        }
    }
}
