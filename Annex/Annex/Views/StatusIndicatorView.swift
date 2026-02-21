import SwiftUI

// Avatar with status ring — matches Clubhouse's AgentListItem
struct AgentAvatarView: View {
    let color: String
    let status: AgentStatus?
    let state: AgentState?
    var size: CGFloat = 36

    private var ringColor: Color {
        switch state {
        case .working: .green
        case .needsPermission: .orange
        case .toolError: .yellow
        default:
            switch status {
            case .running: .green
            case .sleeping: .gray
            case .error: .red
            case nil: .gray
            }
        }
    }

    var body: some View {
        Circle()
            .fill(AgentColor.color(for: color))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(ringColor, lineWidth: 2.5)
                    .frame(width: size + 4, height: size + 4)
            )
    }
}

// Small status dot
struct StatusDotView: View {
    let status: AgentStatus
    var size: CGFloat = 8

    private var color: Color {
        switch status {
        case .running: .green
        case .sleeping: .yellow
        case .error: .red
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// Chip pill matching Clubhouse's inline badges
struct ChipView: View {
    let text: String
    let bg: Color
    let fg: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
    }
}

// Orchestrator chip colors matching Clubhouse
enum OrchestratorColors {
    static func colors(for id: String?) -> (bg: Color, fg: Color) {
        switch id {
        case "claude-code":
            return (Color(hex: "#fb923c").opacity(0.2), Color(hex: "#fb923c"))
        case "copilot-cli":
            return (Color(hex: "#60a5fa").opacity(0.2), Color(hex: "#60a5fa"))
        default:
            return (Color(hex: "#94a3b8").opacity(0.2), Color(hex: "#94a3b8"))
        }
    }
}

// Model chip color — hash-based 7-color palette matching Clubhouse
enum ModelColors {
    private static let palette: [(bg: Color, fg: Color)] = [
        (Color.purple.opacity(0.15), .purple),
        (Color.teal.opacity(0.15), .teal),
        (Color.pink.opacity(0.15), .pink),
        (Color.green.opacity(0.15), .green),
        (Color(hex: "#f59e0b").opacity(0.15), Color(hex: "#f59e0b")),
        (Color.indigo.opacity(0.15), .indigo),
        (Color(hex: "#0ea5e9").opacity(0.15), Color(hex: "#0ea5e9")),
    ]

    static func colors(for model: String?) -> (bg: Color, fg: Color) {
        guard let model else { return palette[0] }
        let hash = abs(model.hashValue)
        return palette[hash % palette.count]
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            AgentAvatarView(color: "emerald", status: .running, state: .working)
            AgentAvatarView(color: "rose", status: .sleeping, state: nil)
            AgentAvatarView(color: "amber", status: .error, state: .toolError)
        }
        HStack(spacing: 8) {
            ChipView(text: "CC", bg: Color(hex: "#fb923c").opacity(0.2), fg: Color(hex: "#fb923c"))
            ChipView(text: "Opus", bg: .purple.opacity(0.15), fg: .purple)
            ChipView(text: "Free", bg: .red.opacity(0.15), fg: .red)
        }
    }
    .padding()
}
