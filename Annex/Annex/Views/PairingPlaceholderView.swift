import SwiftUI

struct PairingPlaceholderView: View {
    @Environment(AppStore.self) private var store
    @State private var pin: String = ""

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(store.theme.accentColor)
                .padding(24)
                .glassEffect(.regular.tint(store.theme.accentColor.opacity(0.2)), in: Circle())

            VStack(spacing: 8) {
                Text("Connect to Clubhouse")
                    .font(.title2.weight(.semibold))
                Text("Enter the PIN shown in Clubhouse desktop app under Settings > Annex")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            TextField("000000", text: $pin)
                .keyboardType(.numberPad)
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
                .textFieldStyle(.roundedBorder)

            Button {
                store.isPaired = true
                store.loadMockData()
            } label: {
                Text("Connect")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(store.theme.accentColor)
            .disabled(pin.count < 6)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(store.theme.baseColor)
    }
}

#Preview {
    PairingPlaceholderView()
        .environment(AppStore())
}
