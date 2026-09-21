import Foundation
import Observation
import UniformTypeIdentifiers

/// État de la bibliothèque tel que l'interface le voit.
///
/// Ce type ne sait pas lire un fichier : il délègue tout à une `AudioSource`.
/// C'est ce qui rend l'ajout d'une source distante indolore — il suffira de
/// lui passer une autre implémentation du protocole.
@MainActor
@Observable
final class LibraryModel {

    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var tracks: [Track] = []
    private(set) var state: LoadingState = .idle

    /// Message d'erreur non bloquant affiché à l'utilisateur (import partiel,
    /// fichier illisible…). L'interface le présente puis l'efface.
    var lastMessage: String?

    /// Texte de recherche. Simple filtre sur le titre, l'artiste et l'album.
    var searchText: String = ""

    let source: AudioSource

    /// Empêche deux rafraîchissements simultanés (lancement + retour au
    /// premier plan peuvent se déclencher coup sur coup).
    @ObservationIgnored private var isRefreshing = false

    init(source: AudioSource) {
        self.source = source
    }

    var importingSource: ImportingAudioSource? {
        source as? ImportingAudioSource
    }

    var supportedContentTypes: [UTType] {
        importingSource?.supportedContentTypes ?? [.audio]
    }

    var isEmpty: Bool { tracks.isEmpty }

    var filteredTracks: [Track] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tracks }
        return tracks.filter { track in
            track.title.localizedCaseInsensitiveContains(query)
                || (track.artist?.localizedCaseInsensitiveContains(query) ?? false)
                || (track.album?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func track(with id: TrackID) -> Track? {
        tracks.first { $0.id == id }
    }

    // MARK: - Chargement

    /// Recharge la bibliothèque depuis la source.
    ///
    /// Appelée au lancement et à chaque retour au premier plan : l'utilisateur
    /// peut avoir déposé des fichiers via l'app Fichiers pendant ce temps.
    func refresh(pruning store: PreferencesStore? = nil) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if state != .loaded { state = .loading }
        do {
            let loaded = try await source.loadTracks()
            tracks = loaded
            state = .loaded
            store?.prune(keeping: Set(loaded.map(\.id)))
        } catch {
            state = .failed(error.localizedDescription)
            lastMessage = error.localizedDescription
        }
    }

    // MARK: - Import / suppression

    func importFiles(_ urls: [URL]) async {
        guard let importing = importingSource, !urls.isEmpty else { return }
        let result = await importing.importTracks(from: urls)

        if !result.imported.isEmpty {
            await refresh()
        }

        if result.failures.isEmpty {
            let count = result.imported.count
            lastMessage = count == 1
                ? "1 morceau ajouté."
                : "\(count) morceaux ajoutés."
        } else {
            let failed = result.failures.count
            lastMessage = "\(result.imported.count) ajouté(s), \(failed) ignoré(s) (format non lu)."
        }
    }

    func delete(_ track: Track, store: PreferencesStore) async {
        guard let importing = importingSource else { return }
        do {
            try await importing.deleteTrack(track)
            tracks.removeAll { $0.id == track.id }
            store.prune(keeping: Set(tracks.map(\.id)))
        } catch {
            lastMessage = "Suppression impossible : \(error.localizedDescription)"
        }
    }
}
