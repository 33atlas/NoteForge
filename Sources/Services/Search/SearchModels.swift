import Foundation

// MARK: - Search Models

/// Represents a single search result with relevance scoring
struct SearchResult: Identifiable, Equatable {
    let id: UUID
    let noteId: UUID
    let title: String
    let content: String
    let snippet: String
    let score: Double
    let matchType: MatchType
    let matchedTerms: [String]
    let updatedAt: Date
    let tags: [String]
    
    enum MatchType: String, Codable {
        case fullText = "fts"
        case semantic = "semantic"
        case hybrid = "hybrid"
        case tag = "tag"
        case date = "date"
    }
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id && lhs.noteId == rhs.noteId
    }
}

/// Parsed search query with extracted components
struct ParsedQuery {
    let rawQuery: String
    let plainTerms: [String]
    let tags: [String]
    let paths: [String]
    let dateRange: DateRange?
    let operators: [String: String]
    
    struct DateRange {
        let start: Date?
        let end: Date?
        let modifier: Modifier
        
        enum Modifier {
            case today
            case yesterday
            case thisWeek
            case thisMonth
            case thisYear
            case before
            case after
            case range
        }
    }
    
    var isEmpty: Bool {
        plainTerms.isEmpty && tags.isEmpty && paths.isEmpty && dateRange == nil
    }
}

/// Search options configuration
struct SearchOptions {
    var limit: Int = 20
    var offset: Int = 0
    var includeContent: Bool = true
    var snippetLength: Int = 150
    var boostRecent: Bool = true
    var boostTitleMatches: Bool = true
    var titleWeight: Double = 2.0
    var ftsWeight: Double = 0.5
    var semanticWeight: Double = 0.5
    
    static let `default` = SearchOptions()
}

/// Search mode selection
enum SearchMode {
    case fullText      // FTS5 only
    case semantic     // Vector only
    case hybrid       // Combined
    case tag          // Tag filtering
    case date         // Date filtering
    case auto         // Smart selection based on query
}

/// Note index entry for search
struct NoteIndexEntry: Codable {
    let noteId: UUID
    let title: String
    let content: String
    let tokens: [String]
    let tags: [String]
    let path: String
    let createdAt: Date
    let updatedAt: Date
    let embedding: [Float]?
    
    init(
        noteId: UUID,
        title: String,
        content: String,
        tags: [String] = [],
        path: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        embedding: [Float]? = nil
    ) {
        self.noteId = noteId
        self.title = title
        self.content = content
        self.tokens = Self.tokenize(content: "\(title) \(content)")
        self.tags = tags
        self.path = path
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.embedding = embedding
    }
    
    private static func tokenize(content: String) -> [String] {
        let lowercased = content.lowercased()
        let cleaned = lowercased.replacingOccurrences(
            of: #"[^\w\s]"#,
            with: " ",
            options: .regularExpression
        )
        return cleaned.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && $0.count > 2 }
    }
}

// MARK: - Embedding Protocol

protocol EmbeddingProvider {
    func embed(text: String) async throws -> [Float]
    func embedBatch(texts: [String]) async throws -> [[Float]]
}

// MARK: - Similarity Metrics

enum SimilarityMetric {
    case cosine
    case euclidean
    case dotProduct
    
    func compute(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count else { return 0 }
        
        switch self {
        case .cosine:
            return cosineSimilarity(a, b)
        case .euclidean:
            return euclideanDistance(a, b)
        case .dotProduct:
            return dotProduct(a, b)
        }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        let dot = zip(a, b).map(*).reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magA > 0 && magB > 0 else { return 0 }
        return Double(dot) / (Double(magA) * Double(magB))
    }
    
    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Double {
        let sum = zip(a, b).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
        return 1.0 / (1.0 + sqrt(Double(sum)))
    }
    
    private func dotProduct(_ a: [Float], _ b: [Float]) -> Double {
        return Double(zip(a, b).map(*).reduce(0, +))
    }
}
