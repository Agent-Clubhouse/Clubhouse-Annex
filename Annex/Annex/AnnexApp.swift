import SwiftUI

@main
struct AnnexApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            if store.isPaired {
                RootNavigationView()
                    .environment(store)
                    .tint(store.theme.accentColor)
                    .preferredColorScheme(store.theme.isDark ? .dark : .light)
            } else {
                PairingPlaceholderView()
                    .environment(store)
                    .tint(store.theme.accentColor)
                    .preferredColorScheme(store.theme.isDark ? .dark : .light)
            }
        }
    }
}
