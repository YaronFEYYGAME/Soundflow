import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Source audio lisant les fichiers stockés dans le dossier « Documents » de
/// l'application.
///
/// Pourquoi « Documents » et pas un dossier caché ? Parce que, combiné aux
/// options `UIFileSharingEnabled` et `LSSupportsOpeningDocumentsInPlace`
/// déclarées dans les réglages du projet, ce dossier apparaît dans l'app
/// Fichiers de l'iPhone et dans le Finder du Mac. L'utilisateur peut donc
/// déposer ses MP3 par glisser-déposer, sans passer par l'app — et sans que
/// nous ayons une ligne de code à écrire pour ça.
///
/// C'est un `actor` : Swift garantit alors qu'un seul morceau de code à la
/// fois touche au système de fichiers, ce qui élimine par construction toute
/// une famille de bugs de concurrence (deux imports simultanés, un scan
/// pendant une suppression…).
actor LocalAudioSource: ImportingAudioSource {

    nonisolated let id = "local"
    nonisolated let displayName = "Sur cet iPhone"

    /// Extensions reconnues. Le MP3 est l'objectif, mais AVFoundation lit
    /// nativement ces formats : les accepter ne coûte rien et évite des
    /// « pourquoi ce fichier n'apparaît pas ? ».
    nonisolated static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "aac", "wav", "aif", "aiff", "caf", "flac"
    ]

    nonisolated var supportedContentTypes: [UTType] {
        [.mp3, .mpeg4Audio, .wav, .aiff, .audio]
    }

    private let fileManager: FileManager
    private let directory: URL

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            // `Documents` existe toujours sur iOS ; le `!` est ici sans risque
            // réel, mais on garde un repli explicite pour ne jamais planter.
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            self.directory = documents ?? URL(fileURLWithPath: NSTemporaryDirectory())
        }
    }

    /// URL du dossier surveillé.
    ///
    /// Accessible sans `await` : `directory` est une constante fixée à
    /// l'initialisation, donc Swift autorise sa lecture depuis l'extérieur de
    /// l'acteur sans risque.
    nonisolated var directoryURL: URL { directory }

    // MARK: - Lecture de la bibliothèque

    func loadTracks() async throws -> [Track] {
        try ensureDirectoryExists()

        let urls = audioFileURLs()
        guard !urls.isEmpty else { return [] }
        let sourceID = id

        // On lit les métadonnées en parallèle, mais par petits lots : lancer
        // 2 000 lectures de fichiers d'un coup saturerait les entrées/sorties
        // et ferait ramer l'interface.
        var tracks: [Track] = []
        tracks.reserveCapacity(urls.count)

        let batchSize = 8
        var index = 0
        while index < urls.count {
            let batch = Array(urls[index..<min(index + batchSize, urls.count)])
            let batchTracks = await withTaskGroup(of: Track?.self) { group in
                for url in batch {
                    group.addTask { await Self.makeTrack(from: url, sourceID: sourceID) }
                }
                var result: [Track] = []
                for await track in group {
                    if let track { result.append(track) }
                }
                return result
            }
            tracks.append(contentsOf: batchTracks)
            index += batchSize
        }

        return tracks.sorted { lhs, rhs in
            lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    func playbackURL(for track: Track) async throws -> URL {
        let url = directory.appending(path: track.id.key)
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw AudioSourceError.trackNotFound(track.id)
        }
        return url
    }

    func artworkData(for track: Track) async -> Data? {
        let url = directory.appending(path: track.id.key)
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }
        let artworkItems = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierArtwork
        )
        for item in artworkItems {
            if let data = try? await item.load(.dataValue) { return data }
        }
        return nil
    }

    // MARK: - Import et suppression

    func importTracks(from urls: [URL]) async -> (imported: [Track], failures: [AudioSourceError]) {
        var imported: [Track] = []
        var failures: [AudioSourceError] = []

        do {
            try ensureDirectoryExists()
        } catch {
            return ([], [.importFailed(fileName: "dossier Documents", reason: error.localizedDescription)])
        }

        for url in urls {
            // Les fichiers choisis via le sélecteur système vivent hors du
            // bac à sable de l'app. Il faut demander l'accès, et surtout le
            // relâcher ensuite, sinon iOS finit par refuser les suivants.
            let needsScopedAccess = url.startAccessingSecurityScopedResource()
            defer { if needsScopedAccess { url.stopAccessingSecurityScopedResource() } }

            guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else {
                failures.append(.unreadableFile(url))
                continue
            }

            let destination = uniqueDestinationURL(for: url.lastPathComponent)
            do {
                try fileManager.copyItem(at: url, to: destination)
            } catch {
                failures.append(.importFailed(
                    fileName: url.lastPathComponent,
                    reason: error.localizedDescription
                ))
                continue
            }

            if let track = await Self.makeTrack(from: destination, sourceID: id) {
                imported.append(track)
            } else {
                // Fichier copié mais illisible : on le retire pour ne pas
                // laisser de déchet dans la bibliothèque.
                try? fileManager.removeItem(at: destination)
                failures.append(.unreadableFile(url))
            }
        }

        return (imported, failures)
    }

    func deleteTrack(_ track: Track) async throws {
        let url = directory.appending(path: track.id.key)
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try fileManager.removeItem(at: url)
    }

    // MARK: - Utilitaires internes

    private func ensureDirectoryExists() throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directory.path(percentEncoded: false), isDirectory: &isDirectory) {
            if isDirectory.boolValue { return }
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func audioFileURLs() -> [URL] {
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )) ?? []

        return contents.filter { url in
            Self.supportedExtensions.contains(url.pathExtension.lowercased())
        }
    }

    private func uniqueDestinationURL(for fileName: String) -> URL {
        let candidate = directory.appending(path: fileName)
        guard fileManager.fileExists(atPath: candidate.path(percentEncoded: false)) else {
            return candidate
        }
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var suffix = 2
        while true {
            let name = ext.isEmpty ? "\(base) (\(suffix))" : "\(base) (\(suffix)).\(ext)"
            let url = directory.appending(path: name)
            if !fileManager.fileExists(atPath: url.path(percentEncoded: false)) { return url }
            suffix += 1
            if suffix > 9_999 { return directory.appending(path: "\(UUID().uuidString).\(ext)") }
        }
    }

    // MARK: - Lecture des métadonnées

    /// Construit un `Track` à partir d'un fichier, en lisant ses tags ID3.
    /// Renvoie `nil` si le fichier n'est pas lisible : un fichier corrompu ne
    /// doit jamais entrer dans la bibliothèque (c'est la première cause de
    /// blocage en cours d'écoute).
    private static func makeTrack(from url: URL, sourceID: String) async -> Track? {
        let asset = AVURLAsset(url: url)

        guard let isPlayable = try? await asset.load(.isPlayable), isPlayable else { return nil }

        var title: String?
        var artist: String?
        var album: String?

        if let metadata = try? await asset.load(.commonMetadata) {
            title = await stringValue(in: metadata, identifier: .commonIdentifierTitle)
            artist = await stringValue(in: metadata, identifier: .commonIdentifierArtist)
            album = await stringValue(in: metadata, identifier: .commonIdentifierAlbumName)
        }

        var duration: TimeInterval?
        if let cmDuration = try? await asset.load(.duration), cmDuration.isNumeric {
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite, seconds > 0 { duration = seconds }
        }

        let fileName = url.lastPathComponent
        let addedAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()

        return Track(
            id: TrackID(sourceID: sourceID, key: fileName),
            title: title?.nonEmpty ?? (fileName as NSString).deletingPathExtension,
            artist: artist?.nonEmpty,
            album: album?.nonEmpty,
            duration: duration,
            addedAt: addedAt
        )
    }

    private static func stringValue(
        in metadata: [AVMetadataItem],
        identifier: AVMetadataIdentifier
    ) async -> String? {
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier)
        for item in items {
            if let value = try? await item.load(.stringValue), let value = value.nonEmpty {
                return value
            }
        }
        return nil
    }
}

private extension String {
    /// `nil` plutôt qu'une chaîne vide ou remplie d'espaces : cela simplifie
    /// tous les affichages en aval.
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
