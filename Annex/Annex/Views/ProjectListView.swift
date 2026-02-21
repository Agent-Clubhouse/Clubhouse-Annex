import SwiftUI

struct ProjectListView: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedProject: Project?
    @State private var showSettings = false

    var body: some View {
        List(store.projects, selection: $selectedProject) { project in
            ProjectRowView(
                project: project,
                agentCount: store.agents(for: project).count
            )
            .tag(project)
            .listRowBackground(store.theme.surface0Color.opacity(0.5))
        }
        .scrollContentBackground(.hidden)
        .background(store.theme.baseColor)
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    @Previewable @State var selected: Project? = nil
    let store = AppStore()
    store.loadMockData()
    return NavigationStack {
        ProjectListView(selectedProject: $selected)
    }
    .environment(store)
}
