import SwiftUI

struct SendMessageSheet: View {
    let agent: DurableAgent

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Message") {
                    TextField("Send a message to \(agent.name ?? "the agent")...", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Send Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await send() }
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func send() async {
        isSubmitting = true
        errorMessage = nil

        do {
            try await store.sendMessage(
                agentId: agent.id,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
            isSubmitting = false
        }
    }
}

#Preview {
    let store = AppStore()
    store.loadMockData()
    return SendMessageSheet(agent: MockData.agents["proj_001"]![0])
        .environment(store)
}
