import SwiftUI

struct AgentRowView: View {
    let agent: DurableAgent
    @Environment(AppStore.self) private var store

    private var preview: String {
        if agent.status == .running, let msg = agent.detailedStatus?.message, !msg.isEmpty {
            return msg
        }
        if let mission = agent.mission {
            return mission
        }
        return agent.status == .sleeping ? "Sleeping" : ""
    }

    private var modelLabel: String? {
        let model = agent.model
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return model
    }

    private var orchestratorLabel: String? {
        guard let orchId = agent.orchestrator,
              let info = store.orchestrators[orchId] else { return nil }
        return info.shortName
    }

    var body: some View {
        HStack(spacing: 12) {
            AgentAvatarView(
                color: agent.color,
                status: agent.status,
                state: agent.detailedStatus?.state
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(agent.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    if let label = orchestratorLabel {
                        let c = OrchestratorColors.colors(for: agent.orchestrator)
                        ChipView(text: label, bg: c.bg, fg: c.fg)
                    }
                    if let label = modelLabel {
                        let c = ModelColors.colors(for: agent.model)
                        ChipView(text: label, bg: c.bg, fg: c.fg)
                    }
                    if agent.freeAgentMode {
                        ChipView(text: "Free", bg: .red.opacity(0.15), fg: .red)
                    }
                }

                if !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let ts = agent.detailedStatus?.timestamp {
                Text(relativeTime(from: ts))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct QuickAgentRowView: View {
    let agent: QuickAgent

    private var preview: String {
        agent.mission ?? ""
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: agent.status == .running ? "bolt.fill" : "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(agent.status == .running ? .orange : .green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(agent.name)
                        .font(.body.weight(.medium))
                    if let model = agent.model {
                        let label = model.contains("opus") ? "Opus"
                            : model.contains("sonnet") ? "Sonnet"
                            : model.contains("haiku") ? "Haiku" : model
                        let c = ModelColors.colors(for: model)
                        ChipView(text: label, bg: c.bg, fg: c.fg)
                    }
                }
                if !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let status = agent.status {
                StatusDotView(status: status)
            }
        }
        .padding(.vertical, 4)
    }
}

private func relativeTime(from unixMs: Int) -> String {
    let seconds = max(0, (Int(Date().timeIntervalSince1970 * 1000) - unixMs) / 1000)
    if seconds < 60 { return "now" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    return "\(hours / 24)d"
}

#Preview {
    let store = AppStore()
    store.loadMockData()
    return List {
        AgentRowView(agent: MockData.agents["proj_001"]![0])
        AgentRowView(agent: MockData.agents["proj_001"]![1])
        AgentRowView(agent: MockData.agents["proj_002"]![0])
        AgentRowView(agent: MockData.agents["proj_002"]![1])
    }
    .environment(store)
}
