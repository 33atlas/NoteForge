import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var noteStore: NoteStore
    @AppStorage("notesDirectory") private var notesDirectory: String = ""
    @AppStorage("aiProvider") private var aiProvider: String = "local"
    @AppStorage("localModelPath") private var localModelPath: String = ""
    @AppStorage("cloudAPIKey") private var cloudAPIKey: String = ""
    @AppStorage("globalHotkey") private var globalHotkey: String = "cmd+shift+n"
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                notesDirectory: $notesDirectory,
                globalHotkey: $globalHotkey
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AISettingsView(
                aiProvider: $aiProvider,
                localModelPath: $localModelPath,
                cloudAPIKey: $cloudAPIKey
            )
            .tabItem {
                Label("AI", systemImage: "brain")
            }
            
            StorageSettingsView()
                .tabItem {
                    Label("Storage", systemImage: "externaldrive")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @Binding var notesDirectory: String
    @Binding var globalHotkey: String
    
    var body: some View {
        Form {
            Section("Notes Location") {
                TextField("Notes Directory", text: $notesDirectory)
                    .disabled(true)
                
                Button("Change...") {
                    selectNotesDirectory()
                }
            }
            
            Section("Keyboard Shortcuts") {
                Picker("Quick Capture", selection: $globalHotkey) {
                    Text("⌘⇧N").tag("cmd+shift+n")
                    Text("⌥⌘N").tag("opt+cmd+n")
                    Text("⌃⌘N").tag("ctrl+cmd+n")
                }
                .pickerStyle(.segmented)
            }
            
            Section("Appearance") {
                Picker("Theme", selection: .constant("system")) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func selectNotesDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            notesDirectory = url.path
        }
    }
}

struct AISettingsView: View {
    @Binding var aiProvider: String
    @Binding var localModelPath: String
    @Binding var cloudAPIKey: String
    
    var body: some View {
        Form {
            Section("AI Provider") {
                Picker("Processing Mode", selection: $aiProvider) {
                    Text("Local (llama.cpp)").tag("local")
                    Text("Cloud (Anthropic)").tag("cloud")
                    Text("Hybrid (Local first, cloud fallback)").tag("hybrid")
                }
            }
            
            Section("Local Model") {
                TextField("Model Path (.gguf)", text: $localModelPath)
                    .disabled(aiProvider == "cloud")
                
                Button("Browse...") {
                    selectModel()
                }
                .disabled(aiProvider == "cloud")
                
                if aiProvider == "local" || aiProvider == "hybrid" {
                    Text("Download models from huggingface.co")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Cloud API") {
                SecureField("Anthropic API Key", text: $cloudAPIKey)
                    .disabled(aiProvider == "local")
                
                if !cloudAPIKey.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("API key configured")
                            .font(.caption)
                    }
                }
            }
            
            Section("Features") {
                Toggle("Auto-tagging", isOn: .constant(true))
                Toggle("Auto-linking", isOn: .constant(true))
                Toggle("Summarization", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func selectModel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        
        if panel.runModal() == .OK, let url = panel.url {
            localModelPath = url.path
        }
    }
}

struct StorageSettingsView: View {
    @State private var showingExport = false
    @State private var showingImport = false
    
    var body: some View {
        Form {
            Section("Data") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Notes")
                            .font(.headline)
                        Text("\(noteCount()) notes stored")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Storage Size")
                            .font(.headline)
                        Text(storageSize())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            
            Section("Backup") {
                Button("Export Notes...") {
                    exportNotes()
                }
                
                Button("Import Notes...") {
                    importNotes()
                }
            }
            
            Section("Danger Zone") {
                Button("Clear All Data") {
                    // Would show confirmation
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func noteCount() -> Int {
        0 // Would get from NoteStore
    }
    
    private func storageSize() -> String {
        "Calculating..." // Would calculate from file size
    }
    
    private func exportNotes() {
        // Export functionality
    }
    
    private func importNotes() {
        // Import functionality
    }
}
