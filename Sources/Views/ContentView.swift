import SwiftUI

struct ContentView: View {
    @EnvironmentObject var noteStore: NoteStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } content: {
            NoteListView()
        } detail: {
            NoteEditorView()
        }
        .sheet(isPresented: $noteStore.showQuickCapture) {
            QuickCaptureView()
        }
    }
}
