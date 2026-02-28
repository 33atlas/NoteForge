# NoteForge 🧠

AI-powered personal knowledge management for macOS.

Capture quickly, AI organizes automatically, find instantly.

## Features

### ⚡ Quick Capture
- **⌘⇧N** Global hotkey for instant capture
- Text, voice, URL, screenshot support
- Quick capture popover

### 🤖 AI-Powered
- Auto-tagging with AI
- Auto-linking related notes
- Smart summarization
- Local-first (privacy) or cloud fallback

### 📝 Note Management
- Markdown storage (you own your data)
- Full-text search
- Tag-based organization
- Folder support

### 🔍 Powerful Search
- Full-text search (FTS5)
- Semantic search (vectors)
- Hybrid search with reranking
- Tag/date operators

## Screenshots

```
┌──────────┬────────────────┬─────────────────────────────┐
│ Sidebar  │ Note List      │ Editor                       │
│          │                │                              │
│ 📁 All   │ 🔍 Search...  │ # Note Title                 │
│ 📁 Today │ ────────────  │                              │
│ 🏷️ Tags  │ Note Preview  │ [Markdown content...]       │
│   #work  │ Note Preview  │                              │
│   #ideas │ Note Preview  │ #tag1 #tag2                  │
└──────────┴────────────────┴─────────────────────────────┘
```

## Architecture

```
┌─────────────────────────────────────────┐
│        SwiftUI + AppKit Hybrid          │
├─────────────────────────────────────────┤
│  Capture: Hotkey, Voice, OCR, URL      │
├─────────────────────────────────────────┤
│  AI: Local (llama.cpp) + Cloud         │
├─────────────────────────────────────────┤
│  Storage: Markdown + SQLite + Vectors  │
├─────────────────────────────────────────┤
│  Search: BM25 + Semantic + Reranking   │
└─────────────────────────────────────────┘
```

## Building

### Prerequisites
- macOS 14.0+
- Xcode 15+

### Build
```bash
cd NoteForge
swift build
```

Or open in Xcode:
```bash
open NoteForge.xcodeproj
```

## Tech Stack

- **UI**: SwiftUI + AppKit
- **Storage**: Markdown files + SQLite
- **AI**: llama.cpp (local) + Anthropic (cloud)
- **Search**: FTS5 + vector embeddings

## License

MIT
