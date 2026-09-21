import Foundation
import UniformTypeIdentifiers

/// Erreurs qu'une source audio peut remonter.
enum AudioSourceError: LocalizedError, Sendable {
    case trackNotFound(TrackID)
    case importFailed(fileName: String, reason: String)
    case unreadableFile(URL)

    var errorDescription: String? {
        switch self {
        case .trackNotFound(let id):
            return "Le morceau « \(id.key) » est introuvable."
        case .importFailed(let fileName, let reason):
            return "Impossible d'importer « \(fileName) » : \(reason)"
        case .unreadableFile(let url):
            return "Le fichier « \(url.lastPathComponent) » n'a pas pu être lu."
        }
    }
}

/// Contrat que doit remplir **toute** provenance de fichiers audio.
///
/// C'est la frontière centrale de l'architecture. Le lecteur ne connaît que
/// ce protocole ; il ignore totalement s'il parle à un dossier local, à iCloud
/// Drive ou à Dropbox.
///
/// Deux choix méritent une explication :
///
/// 1. **Tout est `async`.** Lire un dossier local est quasi instantané, mais
///    interroger un service distant ne l'est pas. En rendant le contrat
///    asynchrone dès maintenant, brancher une source réseau plus tard ne
///    demandera aucune modification du lecteur ni de l'interface.
///
/// 2. **`playbackURL(for:)` est une méthode, pas une propriété de `Track`.**
///    Une source distante devra peut-être télécharger le fichier dans un cache
///    ou générer une URL temporaire signée. Passer par une méthode laisse toute
///    liberté de faire ce travail au dernier moment.
protocol AudioSource: Sendable {
    /// Identifiant technique stable, repris dans chaque `TrackID`
    /// (ex. `"local"`). Ne doit jamais changer, sinon les préférences
    /// enregistrées seraient orphelines.
    var id: String { get }

    /// Nom affiché à l'utilisateur (ex. « Sur cet iPhone »).
    var displayName: String { get }

    /// Liste complète des morceaux disponibles dans cette source.
    func loadTracks() async throws -> [Track]

    /// URL réellement lisible par le moteur audio.
    func playbackURL(for track: Track) async throws -> URL

    /// Pochette éventuelle, chargée à la demande (jamais en masse : sur une
    /// grosse bibliothèque cela consommerait beaucoup de mémoire pour rien).
    func artworkData(for track: Track) async -> Data?
}

extension AudioSource {
    func artworkData(for track: Track) async -> Data? { nil }
}

/// Capacité **optionnelle** : certaines sources acceptent qu'on y ajoute ou
/// qu'on en retire des fichiers, d'autres non (une source en lecture seule,
/// par exemple un partage Dropbox public).
///
/// Séparer cette capacité du protocole principal évite d'obliger les futures
/// sources à implémenter des méthodes qui n'ont pas de sens pour elles.
protocol ImportingAudioSource: AudioSource {
    /// Types de fichiers acceptés à l'import (utilisé par le sélecteur de
    /// fichiers du système).
    var supportedContentTypes: [UTType] { get }

    /// Importe des fichiers et renvoie les morceaux effectivement ajoutés.
    func importTracks(from urls: [URL]) async -> (imported: [Track], failures: [AudioSourceError])

    /// Supprime définitivement un morceau de la source.
    func deleteTrack(_ track: Track) async throws
}
