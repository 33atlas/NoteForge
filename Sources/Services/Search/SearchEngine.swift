import Foundation
import SQLite

/// Main search engine supporting full-text, semantic, and hybrid search
/// Integrates FTS5, ZVec embeddings, and query parsing
final class SearchEngine {
    
    // MARK: - Properties
    
    private let database: Connection?
    private let queryParser: QueryParser
    private let reranker: Reranker
    private var embeddingProvider: EmbeddingProvider?
    private var noteIndex: [UUID: NoteIndexEntry] = [:]
    private let indexQueue = DispatchQueue(label: "com.noteforge.search.index", qos: .utility)
    
    // SQLite/FTS5 table definitions
    private let notesFTS = VirtualTable("notes_fts")
    private let id = SQLite.Expression<String>("id")
    private let title = SQLite.Expression<String>("title")
    private let content = SQLite.Expression<String>("content")
    private let createdAt = SQLite.Expression<Double>("created_at")
    private let updatedAt = SQLite.Expression<Double>("updated_at")
    private let tags = SQLite.Expression<String>("tags")
    private let path = SQLite.Expression<String>("path")
    
    // FTS columns
    private let ftsRowId = SQLite.Expression<Int64>("rowid")
    private let ftsTitle = SQLite.Expression<String>("title")
    private let ftsContent = SQLite.Expression<String>("content")
    
    // MARK: - Initialization
    
    init(database: Connection? = nil, embeddingProvider: EmbeddingProvider? = nil) {
        self.database = database ?? DatabaseManager.shared.db
        self.queryParser = QueryParser()
        self.reranker = Reranker()
        self.embeddingProvider = embeddingProvider
        
        setupFTS()
        loadIndex()
    }
    
    // MARK: - Setup
    
    private func setupFTS() {
        guard let db = database else { return }
        
        do {
            // Create FTS5 virtual table for full-text search
            try db.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
                    note_id UNINDEXED,
                    title,
                    content,
                    tags UNINDEXED,
                    path UNINDEXED,
                    created_at UNINDEXED,
                    updated_at UNINDEXED,
                    tokenize='porter unicode61'
                )
            """)
        } catch {
            print("FTS setup failed: \(error)")
        }
    }
    
    private func loadIndex() {
        // Load existing notes into memory index
        // This would be called on startup and kept fresh
    }
    
    // MARK: - Public Search API
    
    /// Search with automatic mode detection
    func search(query: String, options: SearchOptions = .default) async throws -> [SearchResult] {
        let parsed = queryParser.parse(query)
        let mode = queryParser.detectSearchMode(parsed)
        
        return try await search(query: parsed, mode: mode, options: options)
    }
    
    /// Search with explicit mode
    func search(
        query: String,
        mode: SearchMode,
        options: SearchOptions = .default
    ) async throws -> [SearchResult] {
        let parsed = queryParser.parse(query)
        return try await search(query: parsed, mode: mode, options: options)
    }
    
    /// Core search implementation
    func search(
        query: ParsedQuery,
        mode: SearchMode,
        options: SearchOptions = .default
    ) async throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        switch mode {
        case .fullText:
            return try await searchFullText(query: query, options: options)
        case .semantic:
            return try await searchSemantic(query: query, options: options)
        case .hybrid:
            return try await searchHybrid(query: query, options: options)
        case .tag:
            return try await searchByTag(query: query, options: options)
        case .date:
            return try await searchByDate(query: query, options: options)
        case .auto:
            let autoMode = queryParser.detectSearchMode(query)
            return try await search(query: query, mode: autoMode, options: options)
        }
    }
    
    // MARK: - Full-Text Search (FTS5)
    
    /// Perform full-text search using SQLite FTS5
    func searchFullText(
        query: ParsedQuery,
        options: SearchOptions = .default
    ) async throws -> [SearchResult] {
        guard let db = database else {
            throw SearchError.databaseUnavailable
        }
        
        // Build FTS query
        let ftsQuery = buildFTSQuery(query.plainTerms)
        
        var results: [SearchResult] = []
        
        do {
            // Execute FTS search
            let sql = """
                SELECT note_id, title, content, tags, path, created_at, updated_at,
                       bm25(notes_fts) as score
                FROM notes_fts
                WHERE notes_fts MATCH ?
                ORDER BY score
                LIMIT ?
                OFFSET ?
            """
            
            let statement = try db.prepare(sql)
            let rows = try statement.run(ftsQuery, options.limit, options.offset)
            
            for row in rows {
                guard let noteIdStr = row[0] as? String,
                      let noteId = UUID(uuidString: noteIdStr),
                      let noteTitle = row[1] as? String,
                      let noteContent = row[2] as? String,
                      let score = row[7] as? Double else {
                    continue
                }
                
                let noteTags = (row[3] as? String ?? "").components(separatedBy: ",").filter { !$0.isEmpty }
                let notePath = row[4] as? String ?? ""
                let noteCreated = Date(timeIntervalSince1970: row[5] as? Double ?? 0)
                let noteUpdated = Date(timeIntervalSince1970: row[6] as? Double ?? 0)
                
                let snippet = generateSnippet(
                    content: noteContent,
                    terms: query.plainTerms,
                    length: options.snippetLength
                )
                
                let result = SearchResult(
                    id: UUID(),
                    noteId: noteId,
                    title: noteTitle,
                    content: noteContent,
                    snippet: snippet,
                    score: abs(score), // BM25 returns negative scores
                    matchType: .fullText,
                    matchedTerms: query.plainTerms,
                    updatedAt: noteUpdated,
                    tags: noteTags
                )
                
                results.append(result)
            }
        } catch {
            throw SearchError.fullTextFailed(error.localizedDescription)
        }
        
        // Apply filters and rerank
        var filtered = applyFilters(results, query: query)
        return reranker.rerank(filtered, query: query, options: options)
    }
    
    // MARK: - Semantic Search (ZVec)
    
    /// Perform semantic search using vector embeddings
    func searchSemantic(
        query: ParsedQuery,
        options: SearchOptions = .default
    ) async throws -> [SearchResult] {
        guard let embedder = embeddingProvider else {
            throw SearchError.embeddingNotAvailable
        }
        
        // Generate query embedding
        let queryText = query.plainTerms.joined(separator: " ")
        let queryEmbedding = try await embedder.embed(text: queryText)
        
        // Search vectors
        var results: [(note: NoteIndexEntry, score: Double)] = []
        
        for (_, note) in noteIndex {
            guard let noteEmbedding = note.embedding else { continue }
            
            let score = SimilarityMetric.cosine.compute(queryEmbedding, noteEmbedding)
            results.append((note, score))
        }
        
        // Sort by similarity
        results.sort { $0.score > $1.score }
        
        // Convert to SearchResults
        let searchResults = results.prefix(options.limit).map { note, score in
            SearchResult(
                id: UUID(),
                noteId: note.noteId,
                title: note.title,
                content: note.content,
                snippet: generateSnippet(content: note.content, terms: query.plainTerms, length: options.snippetLength),
                score: score,
                matchType: .semantic,
                matchedTerms: query.plainTerms,
                updatedAt: note.updatedAt,
                tags: note.tags
            )
        }
        
        // Apply filters
        var filtered = Array(searchResults)
        filtered = applyFilters(filtered, query: query)
        
        return reranker.rerank(filtered, query: query, options: options)
    }
    
    // MARK: - Hybrid Search
    
    /// Combine full-text and semantic search results
    func searchHybrid(
        query: ParsedQuery,
        options: SearchOptions = .default
    ) async throws -> [SearchResult] {
        // Run both searches in parallel
        async let ftsResults = searchFullText(query: query, options: options)
        async let semanticResults = searchSemantic(query: query, options: options)
        
        let fts = try await ftsResults
        let semantic = try await semanticResults
        
        // If semantic fails, fall back to full-text
        guard !semantic.isEmpty else {
            return fts
        }
        
        // If full-text fails, use semantic
        guard !fts.isEmpty else {
            return semantic
        }
        
        // RRF fusion
        let fused = reranker.reciprocalRankFusion([fts, semantic])
        
        // Apply final filters and rerank
        var filtered = applyFilters(fused, query: query)
        return reranker.rerank(filtered, query: query, options: options)
    }
    
    // MARK: - Tag Search
    
    /// Search by tags
    func searchByTag(
        query: ParsedQuery,
        options: SearchOptions = .default
    ) async throws -> [SearchResult] {
        guard let db = database else {
            throw SearchError.databaseUnavailable
        }
        
        let tagsToSearch = query.tags.isEmpty ? query.plainTerms : query.tags
        
        var results: [SearchResult] = []
        
        for tag in tagsToSearch {
            do {
                let sql = """
                    SELECT note_id, title, content, tags, path, created_at, updated_at
                    FROM notes_fts
                    WHERE tags LIKE ?
                    ORDER BY updated_at DESC
                    LIMIT ?
                """
                
                let statement = try db.prepare(sql)
                let rows = try statement.run("%\(tag)%", options.limit)
                
                for row in rows {
                    guard let noteIdStr = row[0] as? String,
                          let noteId = UUID(uuidString: noteIdStr),
                          let noteTitle = row[1] as? String,
                          let noteContent = row[2] as? String else {
                        continue
                    }
                    
                    let noteTags = (row[3] as? String ?? "").components(separatedBy: ",").filter { !$0.isEmpty }
                    let noteUpdated = Date(timeIntervalSince1970: row[6] as? Double ?? 0)
                    
                    let result = SearchResult(
                        id: UUID(),
                        noteId: noteId,
                        title: noteTitle,
                        content: noteContent,
                        snippet: String(noteContent.prefix(options.snippetLength)),
                        score: 1.0,
                        matchType: .tag,
                        matchedTerms: [tag],
                        updatedAt: noteUpdated,
                        tags: noteTags
                    )
                    
                    results.append(result)
                }
            } catch {
                throw SearchError.tagSearchFailed(error.localizedDescription)
            }
        }
        
        // Remove duplicates
        var unique: [UUID: SearchResult] = [:]
        for result in results {
            unique[result.noteId] = result
        }
        
        return Array(unique.values).sorted { $0.updatedAt > $1.updatedAt }
    }
    
    // MARK: - Date Search
    
    /// Search by date range
    func searchByDate(
        query: ParsedQuery,
        options: SearchOptions = .default
    ) async throws -> [SearchResult] {
        guard let db = database,
              let dateRange = query.dateRange else {
            return []
        }
        
        let (startDate, endDate) = calculateDateRange(dateRange)
        
        var results: [SearchResult] = []
        
        do {
            var sql = """
                SELECT note_id, title, content, tags, path, created_at, updated_at
                FROM notes_fts
                WHERE updated_at >= ? AND updated_at <= ?
                ORDER BY updated_at DESC
                LIMIT ?
            """
            
            var params: [Binding?] = [
                startDate.timeIntervalSince1970,
                endDate.timeIntervalSince1970,
                options.limit
            ]
            
            let statement = try db.prepare(sql)
            let rows = try statement.run(params)
            
            for row in rows {
                guard let noteIdStr = row[0] as? String,
                      let noteId = UUID(uuidString: noteIdStr),
                      let noteTitle = row[1] as? String,
                      let noteContent = row[2] as? String else {
                    continue
                }
                
                let noteTags = (row[3] as? String ?? "").components(separatedBy: ",").filter { !$0.isEmpty }
                let noteUpdated = Date(timeIntervalSince1970: row[6] as? Double ?? 0)
                
                let result = SearchResult(
                    id: UUID(),
                    noteId: noteId,
                    title: noteTitle,
                    content: noteContent,
                    snippet: String(noteContent.prefix(options.snippetLength)),
                    score: 1.0,
                    matchType: .date,
                    matchedTerms: [],
                    updatedAt: noteUpdated,
                    tags: noteTags
                )
                
                results.append(result)
            }
        } catch {
            throw SearchError.dateSearchFailed(error.localizedDescription)
        }
        
        return results
    }
    
    // MARK: - Indexing
    
    /// Index a single note for search
    func indexNote(_ note: Note, path: String = "", embedding: [Float]? = nil) async throws {
        let entry = NoteIndexEntry(
            noteId: note.id,
            title: note.title,
            content: note.content,
            tags: note.tags,
            path: path,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            embedding: embedding
        )
        
        // Update in-memory index
        indexQueue.async {
            self.noteIndex[note.id] = entry
        }
        
        // Update FTS index
        guard let db = database else { return }
        
        do {
            try db.execute("""
                INSERT OR REPLACE INTO notes_fts (note_id, title, content, tags, path, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, [
                note.id.uuidString,
                note.title,
                note.content,
                note.tags.joined(separator: ","),
                path,
                note.createdAt.timeIntervalSince1970,
                note.updatedAt.timeIntervalSince1970
            ])
        } catch {
            throw SearchError.indexingFailed(error.localizedDescription)
        }
    }
    
    /// Remove a note from the index
    func removeFromIndex(noteId: UUID) async throws {
        // Remove from in-memory index
        indexQueue.async {
            self.noteIndex.removeValue(forKey: noteId)
        }
        
        // Remove from FTS
        guard let db = database else { return }
        
        do {
            try db.execute("DELETE FROM notes_fts WHERE note_id = ?", [noteId.uuidString])
        } catch {
            throw SearchError.indexingFailed(error.localizedDescription)
        }
    }
    
    /// Reindex all notes
    func reindexAll(notes: [Note]) async throws {
        // Clear existing index
        guard let db = database else { return }
        
        try db.execute("DELETE FROM notes_fts")
        
        // Re-index all notes
        for note in notes {
            try await indexNote(note)
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildFTSQuery(_ terms: [String]) -> String {
        guard !terms.isEmpty else { return "*" }
        
        return terms
            .map { term -> String in
                if term.hasPrefix("❗") && term.hasSuffix("❗") {
                    // Exact phrase
                    let phrase = String(term.dropFirst().dropLast())
                    return "\"\(phrase)\""
                }
                // Regular term with prefix matching
                return "\(term)*"
            }
            .joined(separator: " ")
    }
    
    private func generateSnippet(content: String, terms: [String], length: Int) -> String {
        guard !terms.isEmpty else {
            return String(content.prefix(length))
        }
        
        let lowerContent = content.lowercased()
        
        // Find first match position
        var firstMatch = content.startIndex
        
        for term in terms {
            let lowerTerm = term.lowercased()
            if let range = lowerContent.range(of: lowerTerm) {
                let pos = lowerContent.distance(from: lowerContent.startIndex, to: range.lowerBound)
                let newPos = max(0, pos - length / 2)
                firstMatch = content.index(content.startIndex, offsetBy: newPos, limitedBy: content.endIndex) ?? content.startIndex
                break
            }
        }
        
        // Extract snippet around match
        let snippet = content[firstMatch...]
        let truncated = snippet.prefix(length)
        
        // Clean up
        var result = String(truncated)
        if result.count >= length {
            result = String(result.prefix(length)) + "..."
        }
        
        return result
    }
    
    private func applyFilters(_ results: [SearchResult], query: ParsedQuery) -> [SearchResult] {
        var filtered = results
        
        // Apply path filter
        if !query.paths.isEmpty {
            // Path filtering would require storing path in results
        }
        
        return filtered
    }
    
    private func calculateDateRange(_ dateRange: ParsedQuery.DateRange) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch dateRange.modifier {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let start = calendar.startOfDay(for: yesterday)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .thisWeek:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (start, now)
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (start, now)
        case .thisYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (start, now)
        case .before:
            return (Date.distantPast, dateRange.end ?? now)
        case .after:
            return (dateRange.start ?? now, Date.distantFuture)
        case .range:
            return (dateRange.start ?? Date.distantPast, dateRange.end ?? Date.distantFuture)
        }
    }
}

// MARK: - Search Errors

enum SearchError: Error, LocalizedError {
    case databaseUnavailable
    case embeddingNotAvailable
    case fullTextFailed(String)
    case semanticFailed(String)
    case hybridFailed(String)
    case tagSearchFailed(String)
    case dateSearchFailed(String)
    case indexingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseUnavailable:
            return "Search database is not available"
        case .embeddingNotAvailable:
            return "Embedding provider not configured for semantic search"
        case .fullTextFailed(let msg):
            return "Full-text search failed: \(msg)"
        case .semanticFailed(let msg):
            return "Semantic search failed: \(msg)"
        case .hybridFailed(let msg):
            return "Hybrid search failed: \(msg)"
        case .tagSearchFailed(let msg):
            return "Tag search failed: \(msg)"
        case .dateSearchFailed(let msg):
            return "Date search failed: \(msg)"
        case .indexingFailed(let msg):
            return "Indexing failed: \(msg)"
        }
    }
}

// MARK: - SQLite Extension for FTS5

extension Connection {
    func execute(_ sql: String, _ bindings: [Binding?] = []) throws {
        try run(sql, bindings)
    }
}
