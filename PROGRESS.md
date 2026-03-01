# NoteForge - Complete PKM System

## What's Built

### ✅ Core App
- **SwiftUI macOS app** with 3-column layout
- **⌘⇧N** Quick capture hotkey
- **⌘N** New note
- **Full-text search** in note list

### ✅ Note Management
- Create, edit, delete notes
- Markdown content with preview toggle
- Tag management (add/remove)
- Source tracking (manual, text, voice, URL, screenshot)
- Auto-save

### ✅ NoteStore Module (Implemented Feb 28, 2026)
- **Note.swift**: Full model with tags, links, source, archive/pin
- **FileStore.swift**: Markdown file I/O with YAML frontmatter
- **DatabaseManager.swift**: SQLite.swift for metadata + tag/link indexes
- **NoteStore.swift**: Unified CRUD, tag/link management
- **NoteStoreTests.swift**: Basic operation tests

### ✅ Storage
- Markdown files in `~/Library/Application Support/NoteForge/Notes/`
- YAML frontmatter for metadata (tags, links, source, dates)
- SQLite database for fast queries and indexing

## Project Structure
```
NoteForge/
├── Sources/
│   ├── App/NoteForgeApp.swift
│   ├── Models/Note.swift
│   ├── Stores/NoteStore.swift
│   └── Views/
│       ├── ContentView.swift
│       ├── SidebarView.swift
│       ├── NoteListView.swift
│       ├── NoteEditorView.swift
│       ├── QuickCaptureView.swift
│       └── SettingsView.swift
├── Resources/
│   ├── Info.plist
│   └── NoteForge.entitlements
├── Package.swift
└── README.md
```

## How to Run

1. Open in Xcode:
   ```bash
   cd ~/.openclaw/workspace/NoteForge
   open NoteForge.xcodeproj
   ```

2. Or build from command line:
   ```bash
   cd ~/.openclaw/workspace/NoteForge
   swift build
   ```

3. Run the built app from `~/.build/debug/NoteForge`

## GitHub
✅ Pushed to: **https://github.com/33atlas/NoteForge**

## Next Steps (for future cron jobs)
- AI pipeline integration (llama.cpp, Instructor)
- Search engine (FTS5 + ZVec)
- Voice capture + OCR
- iCloud sync

---

**MVP complete!** 🎉
