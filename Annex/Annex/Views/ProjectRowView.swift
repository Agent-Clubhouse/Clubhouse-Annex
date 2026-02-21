import SwiftUI

struct ProjectRowView: View {
    let project: Project
    let agentCount: Int

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(AgentColor.color(for: project.color))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

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
    List {
        ProjectRowView(project: MockData.projects[0], agentCount: 2)
        ProjectRowView(project: MockData.projects[1], agentCount: 3)
    }
}
