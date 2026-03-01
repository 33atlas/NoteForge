# NoteForge

A modern personal knowledge management (PKM) app for macOS.

## Requirements

- macOS 13.0 or later
- Xcode 15.0+
- XcodeGen (for generating the Xcode project)

## Setup

### 1. Install XcodeGen

On macOS:
```bash
brew install xcodegen
```

### 2. Generate the Xcode Project

```bash
cd NoteForge
xcodegen generate
```

### 3. Open in Xcode

```bash
open NoteForge.xcodeproj
```

### 4. Build and Run

Press ⌘+R in Xcode, or:
```bash
xcodebuild -project NoteForge.xcodeproj -scheme NoteForge -configuration Debug build
```

## Dependencies

- **SQLite.swift** - SQLite database wrapper
- **Ink** - Fast Markdown parsing
- **HotKey** - Global keyboard shortcuts
- **FileWatcher** - File system monitoring

## Project Structure

```
NoteForge/
├── Sources/
│   ├── App/           # App entry point
│   ├── Models/        # Data models
│   ├── Services/      # Business logic & database
│   └── Views/         # SwiftUI views
├── Resources/         # App resources
├── project.yml        # XcodeGen configuration
└── Package.swift      # Swift Package Manager config
```

## Usage

- **⌘+N** - Create new note
- **⌘+F** - Search notes
- Select a note from the sidebar to view/edit

## License

MIT License
