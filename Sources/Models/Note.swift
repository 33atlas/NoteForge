import Foundation

// MARK: - Note Model

struct Note: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var content: String
    var aiSummary: String?
    var createdAt: Date
    var modifiedAt: Date
    var source: NoteSource
    var tags: [String]
    var links: [NoteLink]
    var folderPath: String?
    var isArchived: Bool
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        aiSummary: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        source: NoteSource = .manual,
        tags: [String] = [],
        links: [NoteLink] = [],
        folderPath: String? = nil,
        isArchived: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.aiSummary = aiSummary
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.source = source
        self.tags = tags
        self.links = links
        self.folderPath = folderPath
        self.isArchived = isArchived
        self.isPinned = isPinned
    }
}

// MARK: - Note Source

enum NoteSource: String, Codable, CaseIterable {
    case manual
    case voice
    case url
    case screenshot
    case clipboard
    case aiGenerated

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .voice: return "Voice"
        case .url: return "URL"
        case .screenshot: return "Screenshot"
        case .clipboard: return "Clipboard"
        case .aiGenerated: return "AI Generated"
        }
    }

    var icon: String {
        switch self {
        case .manual: return "✏️"
        case .voice: return "🎤"
        case .url: return "🔗"
        case .screenshot: return "📸"
        case .clipboard: return "📋"
        case .aiGenerated: return "🤖"
        }
    }
}

// MARK: - Note Link

struct NoteLink: Identifiable, Equatable, Codable {
    var id: UUID { UUID(uuidString: "\(sourceNoteId.uuidString)-\(targetNoteId.uuidString)") ?? UUID() }
    var sourceNoteId: UUID
    var targetNoteId: UUID?
    var targetTitle: String
    var linkType: LinkType
    var confidence: Double
    var createdAt: Date

    init(
        sourceNoteId: UUID,
        targetNoteId: UUID? = nil,
        targetTitle: String = "",
        linkType: LinkType = .wiki,
        confidence: Double = 1.0,
        createdAt: Date = Date()
    ) {
        self.sourceNoteId = sourceNoteId
        self.targetNoteId = targetNoteId
        self.targetTitle = targetTitle
        self.linkType = linkType
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

// MARK: - Link Type

enum LinkType: String, Codable, CaseIterable {
    case wiki
    case related
    case references
    case parent
    case child

    var displayName: String {
        switch self {
        case .wiki: return "Wiki Link"
        case .related: return "Related"
        case .references: return "References"
        case .parent: return "Parent"
        case .child: return "Child"
        }
    }
}

// MARK: - Tag

struct Tag: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var color: String?
    var createdAt: Date
    var noteCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        color: String? = nil,
        createdAt: Date = Date(),
        noteCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.noteCount = noteCount
    }
}
