import SwiftUI

struct QuickAgentDetailView: View {
    let agent: QuickAgent
    @Environment(AppStore.self) private var store

    private var statusLabel: String {
        switch agent.status {
        case .starting: return "Starting"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .sleeping: return "Sleeping"
        case .error: return "Error"
        case nil: return "Unknown"
        }
    }

    private var statusColor: Color {
        switch agent.status {
        case .running, .starting: return .green
        case .completed: return .blue
        case .failed, .error: return .red
        case .cancelled: return .orange
        case .sleeping: return .secondary
        case nil: return .secondary
        }
    }

    var body: some View {
        List {
            // Status section
            Section("Status") {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusLabel)
                        .font(.subheadline)
                }

                if let model = agent.model {
                    let label = model.contains("opus") ? "Opus"
                        : model.contains("sonnet") ? "Sonnet"
                        : model.contains("haiku") ? "Haiku" : model
                    HStack {
                        Text("Model")
                            .foregroundStyle(.secondary)
                        Spacer()
                        let c = ModelColors.colors(for: model)
                        ChipView(text: label, bg: c.bg, fg: c.fg)
                    }
                }

                if agent.freeAgentMode == true {
                    HStack {
                        Text("Mode")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ChipView(text: "Free", bg: .red.opacity(0.15), fg: .red)
                    }
                }
            }

            // Prompt
            if let prompt = agent.prompt ?? agent.mission {
                Section("Prompt") {
                    Text(prompt)
                        .font(.subheadline)
                }
            }

            // Completion summary
            if let summary = agent.summary {
                Section("Summary") {
                    Text(summary)
                        .font(.subheadline)
                }
            }

            // Completion details
            if agent.status == .completed || agent.status == .failed {
                Section("Details") {
                    if let duration = agent.durationMs {
                        HStack {
                            Text("Duration")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatDuration(duration))
                        }
                    }

                    if let cost = agent.costUsd {
                        HStack {
                            Text("Cost")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "$%.2f", cost))
                        }
                    }

                    if let tools = agent.toolsUsed, !tools.isEmpty {
                        HStack(alignment: .top) {
                            Text("Tools")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(tools.joined(separator: ", "))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if let files = agent.filesModified, !files.isEmpty {
                    Section("Files Modified") {
                        ForEach(files, id: \.self) { file in
                            Text(file)
                                .font(.caption)
                                .fontDesign(.monospaced)
                        }
                    }
                }
            }

            // Cancel button for running agents
            if agent.status == .running || agent.status == .starting {
                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await store.cancelQuickAgent(agentId: agent.id)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Cancel Agent")
                            Spacer()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(store.theme.baseColor)
        .navigationTitle(agent.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDuration(_ ms: Int) -> String {
        let seconds = ms / 1000
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes)m \(remainder)s"
    }
}

#Preview {
    let store = AppStore()
    store.loadMockData()
    let agent = QuickAgent(
        id: "quick_001",
        name: "quick-agent-1",
        kind: "quick",
        status: .completed,
        mission: "Fix the login bug",
        prompt: "Fix the login bug in src/auth/login.ts",
        model: "claude-sonnet-4-5",
        detailedStatus: nil,
        orchestrator: "claude-code",
        parentAgentId: nil,
        projectId: "proj_001",
        freeAgentMode: false,
        summary: "Fixed the login bug by correcting the token validation logic in src/auth/login.ts.",
        filesModified: ["src/auth/login.ts", "src/auth/__tests__/login.test.ts"],
        durationMs: 45200,
        costUsd: 0.12,
        toolsUsed: ["Read", "Edit", "Bash"]
    )
    return NavigationStack {
        QuickAgentDetailView(agent: agent)
    }
    .environment(store)
}
