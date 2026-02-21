import SwiftUI

struct AgentListView: View {
    let project: Project
    @Environment(AppStore.self) private var store

    private var durableAgents: [DurableAgent] {
        store.agents(for: project)
    }

    private var quickAgents: [QuickAgent] {
        store.allQuickAgents(for: project)
    }

    var body: some View {
        List {
            if !durableAgents.isEmpty {
                Section("Agents") {
                    ForEach(durableAgents) { agent in
                        NavigationLink(value: agent) {
                            AgentRowView(agent: agent)
                        }
                        .listRowBackground(store.theme.surface0Color.opacity(0.5))
                    }
                }
            }

            if !quickAgents.isEmpty {
                Section("Quick Tasks") {
                    ForEach(quickAgents) { agent in
                        QuickAgentRowView(agent: agent)
                            .listRowBackground(store.theme.surface0Color.opacity(0.5))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(store.theme.baseColor)
        .navigationTitle(project.label)
        .navigationDestination(for: DurableAgent.self) { agent in
            AgentDetailView(agent: agent)
        }
    }
}

#Preview {
    let store = AppStore()
    store.loadMockData()
    return NavigationStack {
        AgentListView(project: MockData.projects[0])
    }
    .environment(store)
}
