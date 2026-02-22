import SwiftUI

struct ProjectRowView: View {
    let project: Project
    let agentCount: Int
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            ProjectIconView(
                name: project.name,
                displayName: project.displayName,
                iconData: store.projectIcons[project.id]
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(project.label)
                    .font(.body.weight(.medium))
                Text("\(agentCount) agent\(agentCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let store = AppStore()
    store.loadMockData()
    return List {
        ProjectRowView(project: MockData.projects[0], agentCount: 2)
        ProjectRowView(project: MockData.projects[1], agentCount: 3)
    }
    .environment(store)
}
