import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var noteStore: NoteStore
    @State private var showingAllNotes = true
    
    var body: some View {
        List(selection: $noteStore.selectedNote) {
            Section("Library") {
                Button(action: {
                    noteStore.selectedFolder = nil
                    showingAllNotes = true
                }) {
                    Label("All Notes", systemImage: "doc.text")
                }
                .buttonStyle(.plain)
                .listRowBackground(noteStore.selectedFolder == nil && showingAllNotes ? Color.accentColor.opacity(0.2) : Color.clear)
                
                Button(action: {
                    noteStore.selectedFolder = nil
                    showingAllNotes = false
                }) {
                    Label("Today", systemImage: "calendar")
                }
                .buttonStyle(.plain)
                .listRowBackground(noteStore.todayNotes.first != nil && !showingAllNotes ? Color.accentColor.opacity(0.2) : Color.clear)
            }
            
            Section("Folders") {
                ForEach(noteStore.folders, id: \.self) { folder in
                    Button(action: {
                        noteStore.selectedFolder = folder
                        showingAllNotes = false
                    }) {
                        Label(folder, systemImage: "folder")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(noteStore.selectedFolder == folder ? Color.accentColor.opacity(0.2) : Color.clear)
                }
            }
            
            Section("Tags") {
                ForEach(noteStore.tags) { tag in
                    Button(action: {
                        noteStore.searchText = "#\(tag.name)"
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(hex: tag.color) ?? .blue)
                                .frame(width: 8, height: 8)
                            Text(tag.name)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section("Quick Actions") {
                Button(action: {
                    noteStore.createNote()
                }) {
                    Label("New Note", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    noteStore.showQuickCapture = true
                }) {
                    Label("Quick Capture", systemImage: "bolt.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .navigationTitle("NoteForge")
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
