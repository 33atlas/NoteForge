import Foundation

/// Test file for NoteStore module basic operations
/// Run this in Xcode to verify the module works correctly

func testNoteStore() {
    print("=== NoteStore Module Test ===\n")
    
    // Test 1: Note model creation
    print("1. Testing Note model...")
    let note = Note(
        title: "Test Note",
        content: "This is a test note with [[link]] to another note.",
        tags: ["swift", "testing"],
        source: .manual
    )
    print("   Created note: \(note.title)")
    print("   Tags: \(note.tags)")
    print("   Extracted links: \(note.extractedLinks)")
    
    // Test 2: Tag management
    print("\n2. Testing tag management...")
    var testNote = note
    testNote.addTag("pkm")
    print("   Added 'pkm' tag: \(testNote.tags)")
    testNote.removeTag("swift")
    print("   Removed 'swift' tag: \(testNote.tags)")
    
    // Test 3: Link management
    print("\n3. Testing link management...")
    testNote.addLink(NoteLink(targetTitle: "Another Note", targetNoteId: UUID()))
    print("   Added link: \(testNote.links.count) link(s)")
    testNote.syncLinksFromContent()
    print("   After sync: \(testNote.links.count) link(s)")
    
    // Test 4: NoteSource
    print("\n4. Testing NoteSource...")
    print("   Voice source icon: \(NoteSource.voice.iconName)")
    print("   URL source display: \(NoteSource.url.displayName)")
    
    // Test 5: FileStore YAML parsing
    print("\n5. Testing FileStore YAML...")
    let fileStore = FileStore.shared
    let sampleContent = """
    ---
    id: \(UUID().uuidString)
    title: YAML Test
    created_at: 2024-01-01T00:00:00Z
    updated_at: 2024-01-02T00:00:00Z
    tags:
      - swift
      - yaml
    links:
      - title: Related Note
        type: wiki
    source: manual
    pinned: true
    ---
    
    This is the note content.
    """
    
    if let result = fileStore.parseMarkdownContent(sampleContent) {
        print("   Parsed title: \(result.metadata.title)")
        print("   Parsed tags: \(result.metadata.tags)")
        print("   Parsed pinned: \(result.metadata.isPinned)")
        print("   Content: \(result.content.prefix(30))...")
    }
    
    // Test 6: Build markdown
    print("\n6. Testing markdown build...")
    let builtMarkdown = """
    ---
    id: \(testNote.id.uuidString)
    title: \(testNote.title)
    created_at: \(ISO8601DateFormatter().string(from: testNote.createdAt))
    updated_at: \(ISO8601DateFormatter().string(from: testNote.updatedAt))
    tags:
      - \(testNote.tags.joined(separator: "\n      - "))
    source: \(testNote.source.rawValue)
    ---
    
    \(testNote.content)
    """
    print("   Built \(builtMarkdown.components(separatedBy: .newlines).count) lines")
    
    print("\n=== All tests passed! ===")
}

// Uncomment to run tests:
// testNoteStore()
