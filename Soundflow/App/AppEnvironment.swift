import Foundation

/// Point unique de construction des objets partagés de l'application.
///
/// C'est ici, et nulle part ailleurs, qu'on décide quelle source audio est
/// utilisée. Le jour où une source iCloud ou Dropbox s'ajoutera, c'est cette
/// seule ligne qui changera — le lecteur et l'interface, eux, ne connaissent
/// que le protocole `AudioSource`.
@MainActor
final class AppEnvironment {
    let preferences: PreferencesStore
    let library: LibraryModel
    let player: PlayerController

    init() {
        let preferences = PreferencesStore()
        let library = LibraryModel(source: LocalAudioSource())
        let player = PlayerController(library: library, store: preferences)

        self.preferences = preferences
        self.library = library
        self.player = player
    }
}
