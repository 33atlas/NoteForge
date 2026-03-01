import Foundation

/// Reranks search results using various algorithms
/// Supports: Reciprocal Rank Fusion (RRF), BM25, learning-to-rank features
final class Reranker {
    
    // MARK: - Configuration
    
    struct RerankConfig {
        var rrfK: Double = 60.0           // RRF k parameter
        var titleBoost: Double = 2.0      // Title match boost
        var recentBoost: Double = 1.5      // Recent notes boost
        var tagBoost: Double = 1.8        // Tag match boost
        var exactBoost: Double = 3.0      // Exact match boost
        var decayFactor: Double = 0.9      // Recency decay per month
        
        static let `default` = RerankConfig()
    }
    
    private let config: RerankConfig
    
    init(config: RerankConfig = .default) {
        self.config = config
    }
    
    // MARK: - Main Rerank Method
    
    /// Rerank search results using multiple signals
    /// - Parameters:
    ///   - results: Array of search results to rerank
    ///   - query: Original parsed query
    ///   - options: Search options
    /// - Returns: Reranked results with updated scores
    func rerank(
        _ results: [SearchResult],
        query: ParsedQuery,
        options: SearchOptions
    ) -> [SearchResult] {
        guard !results.isEmpty else { return [] }
        
        // Apply various boost factors
        var boostedResults = results.map { result -> SearchResult in
            var score = result.score
            
            // Boost title matches
            if options.boostTitleMatches {
                score += titleMatchBoost(result, query: query)
            }
            
            // Boost recent notes
            if options.boostRecent {
                score += recencyBoost(result)
            }
            
            // Boost tag matches
            score += tagMatchBoost(result, query: query)
            
            // Boost exact phrase matches
            score += exactMatchBoost(result, query: query)
            
            return SearchResult(
                id: result.id,
                noteId: result.noteId,
                title: result.title,
                content: result.content,
                snippet: result.snippet,
                score: score,
                matchType: result.matchType,
                matchedTerms: result.matchedTerms,
                updatedAt: result.updatedAt,
                tags: result.tags
            )
        }
        
        // Sort by final score descending
        boostedResults.sort { $0.score > $1.score }
        
        return boostedResults
    }
    
    // MARK: - Reciprocal Rank Fusion
    
    /// Combine results from multiple ranking algorithms using RRF
    /// - Parameter resultSets: Multiple sets of ranked results
    /// - Returns: Fused and reranked results
    func reciprocalRankFusion(_ resultSets: [[SearchResult]]) -> [SearchResult] {
        guard !resultSets.isEmpty else { return [] }
        
        // Score each result by summing reciprocal ranks
        var scores: [UUID: (result: SearchResult, score: Double)] = [:]
        
        for results in resultSets {
            for (rank, result) in results.enumerated() {
                let rrfScore = 1.0 / (config.rrfK + Double(rank + 1))
                
                if let existing = scores[result.noteId] {
                    scores[result.noteId]?.score += rrfScore
                } else {
                    scores[result.noteId] = (result, rrfScore)
                }
            }
        }
        
        // Sort by combined RRF score
        let fused = scores.values
            .map { ($0.result, $0.score) }
            .sorted { $0.1 > $1.1 }
            .map { result, _ in result }
        
        return fused
    }
    
    // MARK: - BM25 Scoring
    
    /// Calculate BM25 score for a document
    /// - Parameters:
    ///   - document: Document text
    ///   - query: Search query terms
    ///   - avgDocLength: Average document length in collection
    ///   - docLength: Current document length
    ///   - docFreq: Document frequency for each term
    ///   - totalDocs: Total number of documents
    /// - Returns: BM25 score
    func bm25Score(
        document: String,
        query: [String],
        avgDocLength: Double,
        docLength: Int,
        docFreq: [String: Int],
        totalDocs: Int
    ) -> Double {
        let k1 = 1.5
        let b = 0.75
        
        var score = 0.0
        let docTerms = Set(document.lowercased().components(separatedBy: .whitespaces))
        
        for term in query {
            let lowercased = term.lowercased()
            
            guard docTerms.contains(lowercased) else { continue }
            
            let df = Double(docFreq[lowercased] ?? 1)
            let idf = log((Double(totalDocs) - df + 0.5) / (df + 0.5) + 1)
            
            // Term frequency in document
            let tf = Double(document.lowercased().components(separatedBy: lowercased).count - 1)
            
            // Term frequency normalization
            let tfNorm = tf * (k1 + 1) / (tf + k1 * (1 - b + b * Double(docLength) / avgDocLength))
            
            score += idf * tfNorm
        }
        
        return score
    }
    
    // MARK: - Boost Methods
    
    private func titleMatchBoost(_ result: SearchResult, query: ParsedQuery) -> Double {
        let titleLower = result.title.lowercased()
        
        for term in query.plainTerms {
            if titleLower.contains(term.lowercased()) {
                return config.titleBoost
            }
        }
        
        // Exact title match
        for term in query.plainTerms where term.count > 3 {
            if titleLower == term.lowercased() {
                return config.exactBoost
            }
        }
        
        return 0
    }
    
    private func recencyBoost(_ result: SearchResult) -> Double {
        let monthsOld = Calendar.current.dateComponents(
            [.month],
            from: result.updatedAt,
            to: Date()
        ).month ?? 0
        
        // Exponential decay based on age
        return config.recentBoost * pow(config.decayFactor, Double(monthsOld))
    }
    
    private func tagMatchBoost(_ result: SearchResult, query: ParsedQuery) -> Double {
        guard !query.tags.isEmpty else { return 0 }
        
        let resultTags = Set(result.tags.map { $0.lowercased() })
        let queryTags = Set(query.tags.map { $0.lowercased() })
        
        let matches = resultTags.intersection(queryTags).count
        return config.tagBoost * Double(matches)
    }
    
    private func exactMatchBoost(_ result: SearchResult, query: ParsedQuery) -> Double {
        // Check for exact phrase matches (marked with ❗)
        for term in query.plainTerms {
            if term.hasPrefix("❗") && term.hasSuffix("❗") {
                let phrase = String(term.dropFirst().dropLast())
                if result.content.lowercased().contains(phrase.lowercased()) ||
                   result.title.lowercased().contains(phrase.lowercased()) {
                    return config.exactBoost
                }
            }
        }
        
        return 0
    }
    
    // MARK: - Diversity Reranking
    
    /// Rerank for result diversity (avoid redundant results)
    func diversify(_ results: [SearchResult], maxSimilar: Double = 0.8) -> [SearchResult] {
        guard results.count > 1 else { return results }
        
        var diversified: [SearchResult] = []
        var usedTerms: [String] = []
        
        for result in results {
            // Extract key terms from result
            let keyTerms = extractKeyTerms(from: result)
            
            // Check similarity to already selected results
            let isRedundant = usedTerms.contains { used in
                similarity(keyTerms, used) > maxSimilar
            }
            
            if !isRedundant {
                diversified.append(result)
                usedTerms.append(contentsOf: keyTerms.prefix(3))
            }
            
            // Limit results
            if diversified.count >= 20 {
                break
            }
        }
        
        return diversified
    }
    
    private func extractKeyTerms(from result: SearchResult) -> [String] {
        let text = "\(result.title) \(result.content)"
        let words = text.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { $0.count > 4 }
        
        // Return unique terms
        return Array(Set(words).prefix(10))
    }
    
    private func similarity(_ a: [String], _ b: [String]) -> Double {
        let setA = Set(a)
        let setB = Set(b)
        
        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
}

// MARK: - Learning to Rank Features

extension Reranker {
    
    /// Feature vector for ML-based reranking
    struct RankingFeature {
        let resultId: UUID
        let bm25Score: Double
        let semanticScore: Double
        let titleMatch: Bool
        let tagMatchCount: Int
        let daysSinceUpdate: Int
        let contentLength: Int
        let matchCount: Int
    }
    
    /// Simple linear reranking using features
    func linearRerank(features: [RankingFeature]) -> [UUID] {
        let weights: [Double] = [1.0, 0.8, 2.0, 0.5, 0.3, 0.1, 0.5]
        
        var scores: [(id: UUID, score: Double)] = []
        
        for feature in features {
            let score =
                weights[0] * feature.bm25Score +
                weights[1] * feature.semanticScore +
                weights[2] * (feature.titleMatch ? 1.0 : 0.0) +
                weights[3] * Double(feature.tagMatchCount) +
                weights[4] * (1.0 / Double(max(1, feature.daysSinceUpdate))) +
                weights[5] * Double(feature.contentLength) / 1000.0 +
                weights[6] * Double(feature.matchCount)
            
            scores.append((feature.resultId, score))
        }
        
        return scores.sorted { $0.score > $1.score }.map { $0.id }
    }
}
