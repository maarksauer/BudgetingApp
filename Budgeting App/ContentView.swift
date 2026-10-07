import SwiftUI

struct ContentView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some View {
        MainTabView()
            .preferredColorScheme(appearance.colorScheme)
    }
}

#Preview {
    ContentView()
}
