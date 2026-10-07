import SwiftUI

struct ContentView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(AppBackup.restoreRevisionKey) private var restoreRevision = ""
    @AppStorage(AppBackup.restoreNoticeKey) private var showRestoreNotice = false

    var body: some View {
        MainTabView()
            .id(restoreRevision)
            .preferredColorScheme(appearance.colorScheme)
            .alert("Backup Restored", isPresented: $showRestoreNotice) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your backup has been restored. The previous data is available under More → Backup & Restore → Before Last Restore.")
            }
    }
}

#Preview {
    ContentView()
}
