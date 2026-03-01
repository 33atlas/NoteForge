import Foundation

/// Parses search queries with support for various operators
/// Supports: tag:, in:, date:, before:, after:, OR, AND, NOT, "exact phrase"
final class QueryParser {
    
    // MARK: - Operator Patterns
    
    private static let operators: [(pattern: String, key: String)] = [
        (#"tag:(\w+)"#, "tag"),
        (#"in:([^\s]+)"#, "path"),
        (#"date:(\w+)"#, "date"),
        (#"before:(\d{4}-\d{2}-\d{2})"#, "before"),
        (#"after:(\d{4}-\d{2}-\d{2})"#, "after"),
        (#"from:(\d{4}-\d{2}-\d{2})"#, "from"),
        (#"to:(\d{4}-\d{2}-\d{2})"#, "to"),
    ]
    
    private static let dateKeywords: [String: ParsedQuery.DateRange.Modifier] = [
        "today": .thisWeek,
        "yesterday": .yesterday,
        "thisweek": .thisWeek,
        "this month": .thisMonth,
        "thisyear": .thisYear,
        "week": .thisWeek,
        "month": .thisMonth,
        "year": .thisYear,
    ]
    
    // MARK: - Main Parse Method
    
    /// Parse a search query string into structured components
    /// - Parameter query: Raw search query (e.g., "tag:swift in:Projects date:thisweek api")
    /// - Returns: ParsedQuery with extracted terms, tags, paths, and date ranges
    func parse(_ query: String) -> ParsedQuery {
        guard !query.isEmpty else {
            return ParsedQuery(rawQuery: "", plainTerms: [], tags: [], paths: [], dateRange: nil, operators: [:])
        }
        
        var remaining = query
        var tags: [String] = []
        var paths: [String] = [:]
        var dateRange: ParsedQuery.DateRange?
        var operators: [String: String] = [:]
        var plainTerms: [String] = []
        
        // Extract tag: operator
        let tagPattern = #"tag:([^\s]+)"#
        if let tagMatches = extractMatches(from: remaining, pattern: tagPattern, group: 1) {
            tags = tagMatches
            remaining = remaining.replacingOccurrences(
                of: #"tag:[^\s]+"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Extract in: operator (folder path)
        let pathPattern = #"in:([^\s]+)"#
        if let pathMatches = extractMatches(from: remaining, pattern: pathPattern, group: 1) {
            paths = pathMatches
            remaining = remaining.replacingOccurrences(
                of: #"in:[^\s]+"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Extract date: operator
        let dateKeywordPattern = #"date:(\w+)"#
        if let dateMatch = extractFirstMatch(from: remaining, pattern: dateKeywordPattern, group: 1) {
            if let modifier = Self.dateKeywords[dateMatch.lowercased()] {
                dateRange = ParsedQuery.DateRange(start: nil, end: nil, modifier: modifier)
            }
            remaining = remaining.replacingOccurrences(
                of: #"date:\w+"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Extract before: operator
        let beforePattern = #"before:(\d{4}-\d{2}-\d{2})"#
        if let beforeDate = extractFirstMatch(from: remaining, pattern: beforePattern, group: 1) {
            let date = parseDate(beforeDate)
            if let date = date {
                dateRange = ParsedQuery.DateRange(start: nil, end: date, modifier: .before)
            }
            operators["before"] = beforeDate
            remaining = remaining.replacingOccurrences(
                of: #"before:\d{4}-\d{2}-\d{2}"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Extract after: operator
        let afterPattern = #"after:(\d{4}-\d{2}-\d{2})"#
        if let afterDate = extractFirstMatch(from: remaining, pattern: afterPattern, group: 1) {
            let date = parseDate(afterDate)
            if let date = date {
                dateRange = ParsedQuery.DateRange(start: date, end: nil, modifier: .after)
            }
            operators["after"] = afterDate
            remaining = remaining.replacingOccurrences(
                of: #"after:\d{4}-\d{2}-\d{2}"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Extract from: and to: for date ranges
        let fromPattern = #"from:(\d{4}-\d{2}-\d{2})"#
        let toPattern = #"to:(\d{4}-\d{2}-\d{2})"#
        
        var fromDate: Date?
        var toDate: Date?
        
        if let fromMatch = extractFirstMatch(from: remaining, pattern: fromPattern, group: 1) {
            fromDate = parseDate(fromMatch)
            operators["from"] = fromMatch
            remaining = remaining.replacingOccurrences(
                of: #"from:\d{4}-\d{2}-\d{2}"#,
                with: "",
                options: .regularExpression
            )
        }
        
        if let toMatch = extractFirstMatch(from: remaining, pattern: toPattern, group: 1) {
            toDate = parseDate(toMatch)
            operators["to"] = toMatch
            remaining = remaining.replacingOccurrences(
                of: #"to:\d{4}-\d{2}-\d{2}"#,
                with: "",
                options: .regularExpression
            )
        }
        
        if fromDate != nil || toDate != nil {
            dateRange = ParsedQuery.DateRange(start: fromDate, end: toDate, modifier: .range)
        }
        
        // Parse remaining text for boolean operators and plain terms
        let processedTerms = processBooleanOperators(remaining.trimmingCharacters(in: .whitespaces))
        plainTerms = processedTerms.filter { !$0.isEmpty }
        
        return ParsedQuery(
            rawQuery: query,
            plainTerms: plainTerms,
            tags: tags,
            paths: paths,
            dateRange: dateRange,
            operators: operators
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractMatches(from text: String, pattern: String, group: Int) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        guard !matches.isEmpty else { return nil }
        
        return matches.compactMap { match in
            guard match.numberOfRanges > group,
                  let range = Range(match.range(at: group), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }
    
    private func extractFirstMatch(from text: String, pattern: String, group: Int) -> String? {
        return extractMatches(from: text, pattern: pattern, group: group)?.first
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    /// Process boolean operators (AND, OR, NOT) and quoted phrases
    private func processBooleanOperators(_ text: String) -> [String] {
        var terms: [String] = []
        var current = text
        
        // Handle quoted phrases - preserve as single term
        let quotePattern = #""([^"]+)""#
        if let quoteRegex = try? NSRegularExpression(pattern: quotePattern, options: []) {
            let range = NSRange(current.startIndex..., in: current)
            let matches = quoteRegex.matches(in: current, options: [], range: range)
            
            for match in matches.reversed() {
                if let phraseRange = Range(match.range(at: 1), in: current) {
                    let phrase = "❗\(current[phraseRange])❗" // Mark for exact matching
                    if let fullRange = Range(match.range, in: current) {
                        current.replaceSubrange(fullRange, with: phrase)
                    }
                }
            }
        }
        
        // Split by AND/OR/NOT operators
        let booleanPattern = #"(?:\s+(AND|OR|NOT)\s+|\s+)"#
        if let regex = try? NSRegularExpression(pattern: booleanPattern, options: .caseInsensitive) {
            let range = NSRange(current.startIndex..., in: current)
            let parts = regex.split(current)
            
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && trimmed.uppercased() != "AND" && trimmed.uppercased() != "OR" && trimmed.uppercased() != "NOT" {
                    terms.append(trimmed)
                }
            }
        }
        
        return terms
    }
    
    // MARK: - Query Expansion
    
    /// Expand query with synonyms and variations
    func expand(_ query: ParsedQuery) -> [String] {
        var expansions: [String] = []
        
        // Add original terms
        expansions.append(query.plainTerms.joined(separator: " "))
        
        // Add individual terms
        expansions.append(contentsOf: query.plainTerms)
        
        // Add stemmed versions (simple suffix removal)
        for term in query.plainTerms where term.count > 4 {
            let stemmed = String(term.dropLast(1))
            if stemmed != term {
                expansions.append(stemmed)
            }
        }
        
        return expansions
    }
    
    // MARK: - Search Mode Detection
    
    /// Determine the appropriate search mode based on the query
    func detectSearchMode(_ query: ParsedQuery) -> SearchMode {
        // If query has only tags, use tag search
        if !query.tags.isEmpty && query.plainTerms.isEmpty && query.dateRange == nil {
            return .tag
        }
        
        // If query has date filters, use date search
        if query.dateRange != nil && query.plainTerms.isEmpty {
            return .date
        }
        
        // If query has only path filters, use full-text with path filter
        if !query.paths.isEmpty && query.plainTerms.isEmpty {
            return .fullText
        }
        
        // Default to hybrid for mixed queries
        return .hybrid
    }
}

// MARK: - QMD Style Search

extension QueryParser {
    
    /// Parse qmd-style search operators
    /// Supports: #tag, [[note]], ^query, -exclude
    func parseQMD(_ query: String) -> ParsedQuery {
        var processed = query
        var tags: [String] = []
        var excludeTerms: [String] = []
        var linkedNotes: [String] = []
        
        // Extract #tags
        let tagPattern = #"#(\w+)"#
        if let tagMatches = extractMatches(from: processed, pattern: tagPattern, group: 1) {
            tags = tagMatches
            processed = processed.replacingOccurrences(
                of: #"#\w+"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Extract [[wikilinks]]
        let linkPattern = #"\[\[([^\]]+)\]\]"#
        if let linkMatches = extractMatches(from: processed, pattern: linkPattern, group: 1) {
            linkedNotes = linkMatches
            processed = processed.replacingOccurrences(
                of: #"\[\[[^\]]+\]\]"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Extract ^queries (backlinks/searches)
        let queryPattern = #"\^(\w+)"#
        if let queryMatches = extractMatches(from: processed, pattern: queryPattern, group: 1) {
            excludeTerms = queryMatches
            processed = processed.replacingOccurrences(
                of: #"\^\w+"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Extract -exclusions
        let excludePattern = #"-(\S+)"#
        if let excludeMatches = extractMatches(from: processed, pattern: excludePattern, group: 1) {
            excludeTerms.append(contentsOf: excludeMatches)
            processed = processed.replacingOccurrences(
                of: #"-\S+"#,
                with: "",
                options: .regularExpression
            )
        }
        
        // Parse the remaining with standard parser
        var parsed = parse(processed.trimmingCharacters(in: .whitespaces))
        
        // Merge qmd-specific data
        parsed = ParsedQuery(
            rawQuery: query,
            plainTerms: parsed.plainTerms + excludeTerms,
            tags: tags + parsed.tags,
            paths: parsed.paths,
            dateRange: parsed.dateRange,
            operators: parsed.operators
        )
        
        return parsed
    }
}
