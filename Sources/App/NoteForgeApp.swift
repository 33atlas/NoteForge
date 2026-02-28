import SwiftUI

@main
struct NoteForgeApp: App {
    @StateObject private var noteStore = NoteStore()
    @State private var searchText = ""
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(noteStore)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    noteStore.createNote()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Quick Capture") {
                    noteStore.showQuickCapture = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(noteStore)
        }
    }
}
