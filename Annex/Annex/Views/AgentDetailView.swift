import SwiftUI

struct AgentDetailView: View {
    let agent: DurableAgent
    @Environment(AppStore.self) private var store

    private var stateMessage: String {
        guard let ds = agent.detailedStatus else {
            return agent.status == .sleeping ? "Sleeping" : ""
        }
        switch ds.state {
        case .idle: return "Idle"
        case .working: return ds.message.isEmpty ? "Working" : ds.message
        case .needsPermission: return "Needs permission"
        case .toolError: return ds.message.isEmpty ? "Error" : ds.message
        }
    }

    private var stateColor: Color {
        guard let ds = agent.detailedStatus else { return .secondary }
        switch ds.state {
        case .idle: return .secondary
        case .working: return .green
        case .needsPermission: return .orange
        case .toolError: return .red
        }
    }

    private var orchestratorLabel: String? {
        guard let orchId = agent.orchestrator,
              let info = store.orchestrators[orchId] else { return nil }
        return info.displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack(spacing: 12) {
                AgentAvatarView(
                    color: agent.color,
                    status: agent.status,
                    state: agent.detailedStatus?.state,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(agent.name)
                            .font(.headline)
                        if agent.freeAgentMode {
                            ChipView(text: "Free", bg: .red.opacity(0.15), fg: .red)
                        }
                    }
                    HStack(spacing: 6) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 6, height: 6)
                        Text(stateMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let label = orchestratorLabel {
                        let c = OrchestratorColors.colors(for: agent.orchestrator)
                        ChipView(text: label, bg: c.bg, fg: c.fg)
                    }
                    let modelLabel = agent.model.replacingOccurrences(of: "claude-", with: "")
                    let c = ModelColors.colors(for: agent.model)
                    ChipView(text: modelLabel, bg: c.bg, fg: c.fg)
                }
            }
            .padding()
            .background(store.theme.surface0Color.opacity(0.5))

            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                Text(agent.branch)
                Spacer()
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(store.theme.mantleColor)

            Divider()

            ActivityFeedView(events: store.activity(for: agent.id))
        }
        .background(store.theme.baseColor)
        .navigationTitle(agent.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let store = AppStore()
    store.loadMockData()
    return NavigationStack {
        AgentDetailView(agent: MockData.agents["proj_001"]![0])
    }
    .environment(store)
}
