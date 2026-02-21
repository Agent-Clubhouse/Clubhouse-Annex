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
                        Text(store.serverName.isEmpty ? "Unknown" : store.serverName)
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
                        connectionStatusView
                    }
                    HStack {
                        Label("Projects", systemImage: "folder")
                        Spacer()
                        Text("\(store.projects.count)")
                            .foregroundStyle(.secondary)
                    }
                    if let host = store.apiClient?.host, let port = store.apiClient?.port {
                        HStack {
                            Label("Address", systemImage: "network")
                            Spacer()
                            Text("\(host):\(port)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Info")
                }

                if let error = store.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
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

    @ViewBuilder
    private var connectionStatusView: some View {
        switch store.connectionState {
        case .connected:
            Text("Connected")
                .foregroundStyle(.green)
        case .reconnecting(let attempt):
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Reconnecting (\(attempt))")
                    .foregroundStyle(.orange)
            }
        case .connecting:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Connecting")
                    .foregroundStyle(.secondary)
            }
        default:
            Text("Disconnected")
                .foregroundStyle(.red)
        }
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
