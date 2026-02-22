import SwiftUI

struct LiveTerminalView: View {
    let agentId: String
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(store.ptyBuffer(for: agentId))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .id("bottom")
            }
            .onChange(of: store.ptyBuffer(for: agentId)) {
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
        .background(.black)
        .navigationTitle("Live Output")
        .navigationBarTitleDisplayMode(.inline)
    }
}
