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
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // L'utilisateur a pu déposer des fichiers depuis l'app
                // Fichiers pendant que Soundflow était en arrière-plan.
                Task {
                    await appEnvironment.library.refresh(pruning: appEnvironment.preferences)
                    appEnvironment.player.libraryDidChange()
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
