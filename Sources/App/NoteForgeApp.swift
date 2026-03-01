import SwiftUI

@main
struct NoteForgeApp: App {
    @StateObject private var noteStore = NoteStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(noteStore)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    noteStore.createNote()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
