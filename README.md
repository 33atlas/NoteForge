# NoteForge

A modern personal knowledge management (PKM) app for macOS.

## Features

- Note taking with markdown support
- SQLite database for persistent storage
- Global hotkeys for quick access
- File watching for external changes

## Dependencies

- [SQLite.swift](https://github.com/stephencelis/SQLite.swift) - Database
- [Ink](https://github.com/JohnSundell/Ink) - Markdown parsing
- [HotKey](https://github.com/soffes/HotKey) - Global keyboard shortcuts
- [FileWatcher](https://github.com/eonist/FileWatcher) - File system monitoring

## Setup

1. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

2. Open in Xcode:
   ```bash
   open NoteForge.xcodeproj
   ```

3. Build and run (Cmd+R)

## Project Structure

- `Sources/` - Swift source files
- `Resources/` - Assets and Info.plist
- `project.yml` - XcodeGen configuration

## License

MIT
