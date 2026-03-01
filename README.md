# NoteForge

A personal knowledge management app for macOS.

## Requirements

- macOS 13.0+
- Xcode 15.0+

## Dependencies

- **SQLite.swift** - Database operations
- **Ink** - Markdown parsing
- **HotKey** - Global keyboard shortcuts
- **FileWatcher** - File system monitoring

## Setup

1. Clone the repository
2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
3. Open `NoteForge.xcodeproj` in Xcode
4. Build and run (⌘R)

## Project Structure

```
NoteForge/
├── Sources/App/
│   ├── NoteForgeApp.swift    # App entry point
│   ├── ContentView.swift     # Main UI
│   ├── Note.swift            # Note model
│   ├── NoteStore.swift       # Note state management
│   └── DatabaseManager.swift # SQLite database
├── Resources/
│   ├── Info.plist
│   └── Assets.xcassets/
├── project.yml               # XcodeGen configuration
└── README.md
```

## Usage

- **⌘N** - Create new note
- Select a note from the sidebar to edit
- Notes are saved automatically to SQLite
- Markdown preview support via Ink library

## License

MIT
