import Foundation
import Observation
import UIKit
import os

/// Les fonds personnalisés : images ou GIF ajoutés par l'utilisateur, dont un
/// seul (ou aucun) est choisi à un instant donné.
///
/// **Où ils vivent.** Dans un sous-dossier `Fonds` du dossier Documents de
/// l'app, visible dans l'app Fichiers comme la musique. On peut donc aussi y
/// déposer des images directement, sans passer par l'app ; elles apparaissent
/// au prochain retour dans Soundflow. La source audio ne lit que la racine du
/// dossier : ce sous-dossier ne pollue pas la bibliothèque.
///
/// **Ce que le choix affecte.** Le fond choisi remplace la pochette des
/// morceaux partout : écran de lecture, barre de lecture, écran verrouillé,
/// centre de contrôle. « Aucun » rend leur pochette aux morceaux.
@MainActor
@Observable
final class BackgroundStore {

    struct Background: Identifiable, Hashable, Sendable {
        /// Nom du fichier : stable, unique dans le dossier.
        let id: String
        let url: URL
        let isAnimated: Bool
        let addedAt: Date
    }

    private(set) var backgrounds: [Background] = []
    private(set) var selectedID: String?

    /// Version fixe et réduite du fond choisi : première image d'un GIF,
    /// image elle-même sinon. C'est elle qu'affichent l'écran verrouillé et la
    /// barre de lecture.
    private(set) var selectedStill: UIImage?

    /// Vignettes de la grille, indexées par identifiant.
    private(set) var thumbnails: [String: UIImage] = [:]

    /// Message non bloquant pour l'utilisateur (ajout réussi, image refusée…).
    var lastMessage: String?

    /// Prévenu à chaque changement de l'image fixe choisie. Le lecteur s'y
    /// abonne pour mettre à jour l'écran verrouillé.
    @ObservationIgnored var onSelectedStillChanged: ((UIImage?) -> Void)?

    var selected: Background? {
        guard let selectedID else { return nil }
        return backgrounds.first { $0.id == selectedID }
    }

    nonisolated static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp"]
    private static let selectionKey = "Soundflow.selectedBackground"

    let directory: URL
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.example.Soundflow", category: "backgrounds")

    /// Jeton de chargement de l'image fixe : si l'utilisateur change de fond
    /// pendant qu'un chargement est en cours, le résultat périmé est ignoré.
    @ObservationIgnored private var stillLoadToken = UUID()

    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        if let directory {
            self.directory = directory
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = documents.appending(path: "Fonds", directoryHint: .isDirectory)
        }
        self.defaults = defaults
        self.selectedID = defaults.string(forKey: Self.selectionKey)
    }

    // MARK: - Chargement

    /// Relit le dossier. Appelé au lancement et à chaque retour au premier
    /// plan (des images ont pu y être déposées depuis l'app Fichiers).
    func refresh() async {
        let directory = directory
        let found = await Task.detached(priority: .utility) {
            BackgroundStore.scan(directory)
        }.value

        backgrounds = found
        let existing = Set(found.map(\.id))
        thumbnails = thumbnails.filter { existing.contains($0.key) }

        if let selectedID, !existing.contains(selectedID) {
            // Le fichier choisi a disparu (supprimé depuis l'app Fichiers) :
            // on revient proprement aux pochettes plutôt que d'afficher du vide.
            select(nil)
        } else if selectedID != nil, selectedStill == nil {
            await loadSelectedStill()
        }

        for background in found where thumbnails[background.id] == nil {
            await loadThumbnail(for: background)
        }
    }

    nonisolated private static func scan(_ directory: URL) -> [Background] {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )) ?? []

        return urls
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .map { url in
                let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return Background(
                    id: url.lastPathComponent,
                    url: url,
                    isAnimated: ImageProcessing.isAnimatedGIF(at: url),
                    addedAt: created
                )
            }
            .sorted { $0.addedAt < $1.addedAt }
    }

    private func loadThumbnail(for background: Background) async {
        let url = background.url
        let image = await Task.detached(priority: .utility) {
            ImageProcessing.downsampledImage(at: url, maxPixelSize: ImageProcessing.thumbnailPixelSize)
        }.value
        if let image { thumbnails[background.id] = image }
    }

    private func loadSelectedStill() async {
        let token = UUID()
        stillLoadToken = token

        guard let background = selected else {
            updateSelectedStill(nil)
            return
        }
        let url = background.url
        let image = await Task.detached(priority: .userInitiated) {
            ImageProcessing.downsampledImage(at: url, maxPixelSize: ImageProcessing.lockScreenPixelSize)
        }.value

        // Entre-temps, l'utilisateur a pu choisir un autre fond.
        guard stillLoadToken == token else { return }
        updateSelectedStill(image)
    }

    private func updateSelectedStill(_ image: UIImage?) {
        selectedStill = image
        onSelectedStillChanged?(image)
    }

    // MARK: - Choix

    /// Choisit un fond, ou aucun (`nil`) pour revenir aux pochettes.
    func select(_ id: String?) {
        selectedID = id
        if let id {
            defaults.set(id, forKey: Self.selectionKey)
        } else {
            defaults.removeObject(forKey: Self.selectionKey)
        }
        selectedStill = nil
        Task { await loadSelectedStill() }
    }

    // MARK: - Ajout et suppression

    /// Ajoute une image à partir de ses octets (sélecteur de photos).
    /// - Returns: `true` si l'image a été ajoutée.
    @discardableResult
    func add(data: Data, selectAfterwards: Bool = true) async -> Bool {
        let directory = directory
        let result: Result<URL, Error> = await Task.detached(priority: .userInitiated) {
            do {
                let prepared = try ImageProcessing.prepareForStorage(data)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let name = "fond-\(UUID().uuidString.prefix(8)).\(prepared.fileExtension)"
                let url = directory.appending(path: name)
                try prepared.data.write(to: url, options: [.atomic])
                return .success(url)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let url):
            await refresh()
            if selectAfterwards { select(url.lastPathComponent) }
            return true
        case .failure(let error):
            logger.error("Ajout de fond impossible: \(error.localizedDescription, privacy: .public)")
            lastMessage = error.localizedDescription
            return false
        }
    }

    /// Ajoute une image choisie dans l'app Fichiers.
    @discardableResult
    func addFile(at url: URL) async -> Bool {
        // Fichier hors du bac à sable de l'app : accès à demander, et à
        // rendre, sans quoi iOS finit par refuser les suivants.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            lastMessage = ImageProcessing.ImportError.unreadable.localizedDescription
            return false
        }
        return await add(data: data)
    }

    func delete(_ background: Background) {
        do {
            try FileManager.default.removeItem(at: background.url)
        } catch {
            lastMessage = "Suppression impossible : \(error.localizedDescription)"
            return
        }
        backgrounds.removeAll { $0.id == background.id }
        thumbnails.removeValue(forKey: background.id)
        if selectedID == background.id { select(nil) }
    }
}
