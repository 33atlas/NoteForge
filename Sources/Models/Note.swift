import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var aiSummary: String?
    var createdAt: Date
    var modifiedAt: Date
    var source: CaptureSource
    var tags: [String]
    var linkedNoteIds: [UUID]
    var folderPath: String?
    
    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        aiSummary: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        source: CaptureSource = .manual,
        tags: [String] = [],
        linkedNoteIds: [UUID] = [],
        folderPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.aiSummary = aiSummary
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.source = source
        self.tags = tags
        self.linkedNoteIds = linkedNoteIds
        self.folderPath = folderPath
    }
    
    var preview: String {
        let lines = content.components(separatedBy: .newlines)
        let previewText = lines.prefix(3).joined(separator: " ")
        return previewText.isEmpty ? "No content" : String(previewText.prefix(150))
    }
}

enum CaptureSource: String, Codable, CaseIterable {
    case manual
    case text
    case voice
    case url
    case screenshot
    case clipboard
    
    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .text: return "Text"
        case .voice: return "Voice"
        case .url: return "URL"
        case .screenshot: return "Screenshot"
        case .clipboard: return "Clipboard"
        }
    }
    
    var icon: String {
        switch self {
        case .manual: return "pencil"
        case .text: return "doc.text"
        case .voice: return "mic"
        case .url: return "link"
        case .screenshot: return "camera"
        case .clipboard: return "doc.on.clipboard"
        }
    }
}

struct Tag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String
    
    init(id: UUID = UUID(), name: String, color: String = "#007AFF") {
        self.id = id
        self.name = name
        self.color = color
    }
}

struct NoteLink: Codable, Equatable {
    let sourceNoteId: UUID
    let targetNoteId: UUID
    let linkType: LinkType
    let confidence: Float
    let createdAt: Date
    
    init(sourceNoteId: UUID, targetNoteId: UUID, linkType: LinkType, confidence: Float) {
        self.sourceNoteId = sourceNoteId
        self.targetNoteId = targetNoteId
        self.linkType = linkType
        self.confidence = confidence
        self.createdAt = Date()
    }
}

enum LinkType: String, Codable, CaseIterable {
    case related
    case references
    case parent
    case child
    
    var displayName: String {
        switch self {
        case .related: return "Related"
        case .references: return "References"
        case .parent: return "Parent"
        case .child: return "Child"
        }
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let note: Note
    let score: Float
    let snippet: String
}
