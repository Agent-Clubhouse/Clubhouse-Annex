import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Server", systemImage: "desktopcomputer")
                        Spacer()
                        Text(store.serverName)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Agents", systemImage: "cpu")
                        Spacer()
                        Text("\(store.runningAgentCount) running")
                            .foregroundStyle(store.theme.accentColor)
                        Text("/ \(store.totalAgentCount)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Theme", systemImage: "paintpalette")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(store.theme.accentColor).frame(width: 10, height: 10)
                            Circle().fill(store.theme.baseColor).frame(width: 10, height: 10)
                            Circle().fill(store.theme.surface0Color).frame(width: 10, height: 10)
                        }
                        Text("Synced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Connection")
                }

                Section {
                    HStack {
                        Label("Status", systemImage: "wifi")
                        Spacer()
                        Text("Connected")
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Label("Projects", systemImage: "folder")
                        Spacer()
                        Text("\(store.projects.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Info")
                }

                Section {
                    Button(role: .destructive) {
                        store.disconnect()
                        dismiss()
                    } label: {
                        Label("Disconnect", systemImage: "wifi.slash")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(store.theme.baseColor)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    let store = AppStore()
    store.loadMockData()
    store.isPaired = true
    return Text("").sheet(isPresented: .constant(true)) {
        SettingsView()
            .environment(store)
    }
}
