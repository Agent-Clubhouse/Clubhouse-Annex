import SwiftUI

struct ActivityFeedView: View {
    let events: [HookEvent]
    @Environment(AppStore.self) private var store
    @State private var selectedPermission: PermissionRequest?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(events) { event in
                        if event.kind == .permissionRequest,
                           let perm = store.pendingPermissions.values.first(where: {
                               $0.agentId == event.agentId && $0.toolName == event.toolName
                           }) {
                            ActivityEventRow(event: event, accent: store.theme.accentColor, isPending: true)
                                .id(event.id)
                                .onTapGesture { selectedPermission = perm }
                        } else {
                            ActivityEventRow(event: event, accent: store.theme.accentColor)
                                .id(event.id)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onChange(of: events.count) {
                if let last = events.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .sheet(item: $selectedPermission) { perm in
            PermissionRequestSheet(permission: perm, agentName: nil)
        }
    }
}

private struct ActivityEventRow: View {
    let event: HookEvent
    let accent: Color
    var isPending: Bool = false

    private var icon: String {
        switch event.kind {
        case .preTool:
            return toolIcon(event.toolName)
        case .postTool:
            return "checkmark.circle"
        case .toolError:
            return "exclamationmark.triangle.fill"
        case .stop:
            return "stop.circle.fill"
        case .notification:
            return "bell.fill"
        case .permissionRequest:
            return "lock.fill"
        }
    }

    private var iconColor: Color {
        switch event.kind {
        case .preTool: accent
        case .postTool: .green
        case .toolError: .red
        case .stop: .secondary
        case .notification: accent
        case .permissionRequest: .orange
        }
    }

    private var description: String {
        switch event.kind {
        case .preTool:
            return event.toolVerb ?? "Using \(event.toolName ?? "tool")"
        case .postTool:
            return "\(event.toolName ?? "Tool") completed"
        case .toolError:
            return event.message ?? "Tool error"
        case .stop:
            return event.message ?? "Agent stopped"
        case .notification:
            return event.message ?? ""
        case .permissionRequest:
            let detail = event.message ?? event.toolName ?? "unknown"
            return isPending ? "Tap to respond: \(detail)" : "Needs permission: \(detail)"
        }
    }

    private var backgroundColor: Color {
        switch event.kind {
        case .permissionRequest: .orange.opacity(0.1)
        case .toolError: .red.opacity(0.1)
        case .stop: .secondary.opacity(0.08)
        default: .clear
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 20, alignment: .center)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(.subheadline)
                Text(formatTime(event.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
    }
}

private func toolIcon(_ toolName: String?) -> String {
    switch toolName {
    case "Edit": return "pencil"
    case "Read": return "doc.text"
    case "Write": return "doc.badge.plus"
    case "Bash": return "terminal"
    case "Glob": return "magnifyingglass"
    case "Grep": return "text.magnifyingglass"
    case "WebSearch": return "globe"
    case "WebFetch": return "arrow.down.circle"
    case "Task": return "arrow.triangle.branch"
    default: return "wrench"
    }
}

private func formatTime(_ unixMs: Int) -> String {
    let date = Date(timeIntervalSince1970: Double(unixMs) / 1000)
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    formatter.dateStyle = .none
    return formatter.string(from: date)
}

#Preview {
    let store = AppStore()
    store.loadMockData()
    return ActivityFeedView(events: MockData.activity["durable_1737000000000_abc123"]!)
        .environment(store)
}
