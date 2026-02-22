import SwiftUI

enum RootTab {
    case agents
    case projects
}

struct RootNavigationView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: RootTab = .agents
    @State private var selectedProject: Project?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Agents", systemImage: "person.3.fill", value: .agents) {
                AllAgentsView()
            }

            Tab("Projects", systemImage: "folder.fill", value: .projects) {
                NavigationSplitView {
                    ProjectListView(selectedProject: $selectedProject)
                } detail: {
                    if let project = selectedProject {
                        NavigationStack {
                            AgentListView(project: project)
                        }
                    } else {
                        ContentUnavailableView(
                            "Select a Project",
                            systemImage: "folder",
                            description: Text("Choose a project from the sidebar to view its agents.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(store.theme.baseColor)
                    }
                }
            }
        }
    }
}

#Preview {
    let store = AppStore()
    store.loadMockData()
    return RootNavigationView()
        .environment(store)
}
