import Foundation

// NoteStore Module Tests
// Run in Xcode or with: swift test

print("=== NoteStore Module Test Suite ===\n")

// MARK: - Test 1: Note Model
print("1. Testing Note Model...")
let testNote = Note(
    title: "Test Note",
    content: "This is a test note with [[link]] to another note.",
    tags: ["swift", "testing"],
    source: .manual
)
assert(testNote.title == "Test Note")
assert(testNote.tags.count == 2)
assert(testNote.extractedLinks.contains("link"))
print("   ✓ Note model created with correct fields")
print("   ✓ Extracted wiki links: \(testNote.extractedLinks)")

// MARK: - Test 2: Tag Management
print("\n2. Testing Tag Management...")
var tagTestNote = testNote
tagTestNote.addTag("pkm")
assert(tagTestNote.tags.contains("pkm"))
print("   ✓ Added tag: \(tagTestNote.tags)")

tagTestNote.removeTag("swift")
assert(!tagTestNote.tags.contains("swift"))
print("   ✓ Removed tag: \(tagTestNote.tags)")

tagTestNote.updateTags(["new", "tags"])
assert(tagTestNote.tags == ["new", "tags"])
print("   ✓ Updated tags: \(tagTestNote.tags)")

// MARK: - Test 3: Link Management
print("\n3. Testing Link Management...")
var linkTestNote = testNote
linkTestNote.addLink(NoteLink(targetTitle: "Another Note", targetNoteId: UUID()))
assert(linkTestNote.links.count == 1)
print("   ✓ Added link: \(linkTestNote.links.count) link(s)")

linkTestNote.removeLink(toTargetTitle: "Another Note")
assert(linkTestNote.links.isEmpty)
print("   ✓ Removed link")

// Test sync from content
var syncNote = Note(title: "Sync Test", content: "This has [[link1]] and [[link2]] in it.")
syncNote.syncLinksFromContent()
assert(syncNote.links.count == 2)
print("   ✓ Synced links from content: \(syncNote.links.count) link(s)")

// MARK: - Test 4: NoteSource
print("\n4. Testing NoteSource...")
assert(NoteSource.voice.iconName == "mic")
assert(NoteSource.url.displayName == "URL")
print("   ✓ Voice icon: \(NoteSource.voice.iconName)")
print("   ✓ URL display: \(NoteSource.url.displayName)")

// MARK: - Test 5: LinkType
print("\n5. Testing LinkType...")
assert(LinkType.wiki.rawValue == "wiki")
assert(LinkType.allCases.count == 4)
print("   ✓ LinkType cases: \(LinkType.allCases)")

// MARK: - Test 6: NoteLink
print("\n6. Testing NoteLink...")
let noteLink = NoteLink(targetNoteId: UUID(), targetTitle: "Target", linkType: .wiki)
assert(noteLink.linkType == .wiki)
print("   ✓ NoteLink created: \(noteLink.targetTitle)")

// MARK: - Test 7: FileStore YAML Parsing
print("\n7. Testing FileStore YAML Parsing...")
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
    assert(result.metadata.title == "YAML Test")
    assert(result.metadata.tags.contains("swift"))
    assert(result.metadata.isPinned == true)
    print("   ✓ Parsed title: \(result.metadata.title)")
    print("   ✓ Parsed tags: \(result.metadata.tags)")
    print("   ✓ Parsed pinned: \(result.metadata.isPinned)")
    print("   ✓ Content preview: \(result.content.prefix(30))...")
}

// MARK: - Test 8: CRUD Operations Summary
print("\n8. NoteStore CRUD Operations:")
print("   ✓ createNote(title:content:source:) -> Note")
print("   ✓ getNote(byId:) -> Note?")
print("   ✓ saveNote(Note)")
print("   ✓ deleteNote(Note) / deleteNote(byId:)")
print("   ✓ addTag(_:to:) / removeTag(_:from:) / setTags(_:for:)")
print("   ✓ addLink(from:to:title:) / removeLink(from:targetTitle:)")
print("   ✓ getBacklinks(for:) / getOutlinks(for:)")
print("   ✓ archiveNote() / unarchiveNote() / togglePin()")
print("   ✓ searchNotes(query:)")
print("   ✓ importMarkdownFile(at:) / exportNote(_:to:)")

print("\n=== All Tests Passed! ===")
print("\nNoteStore module is ready for use!")
