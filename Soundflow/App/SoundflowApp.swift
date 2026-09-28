import SwiftUI

@main
struct SoundflowApp: App {

    @State private var appEnvironment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(appEnvironment.library)
                .environment(appEnvironment.preferences)
                .environment(appEnvironment.player)
                .environment(appEnvironment.backgrounds)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // L'utilisateur a pu, depuis l'app Fichiers, déposer des
                // morceaux ou des fonds, ou remplacer le fichier de réglages
                // (transfert depuis une autre installation). Les réglages
                // sont relus en premier, avant tout le reste.
                appEnvironment.preferences.reloadIfChangedOnDisk()
                Task {
                    await appEnvironment.library.refresh()
                    appEnvironment.player.libraryDidChange()
                    await appEnvironment.backgrounds.refresh()
                }
            case .background, .inactive:
                // Dernière sauvegarde garantie avant une éventuelle mise à
                // mort du processus par le système.
                Task { await appEnvironment.preferences.flush() }
            @unknown default:
                break
            }
        }
    }
}
