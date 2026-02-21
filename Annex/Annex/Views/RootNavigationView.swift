import SwiftUI

struct RootNavigationView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedProject: Project?

    var body: some View {
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

#Preview {
    let store = AppStore()
    store.loadMockData()
    return RootNavigationView()
        .environment(store)
}
