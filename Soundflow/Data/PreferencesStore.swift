import Foundation
import Observation
import os

/// Format du fichier enregistré sur disque.
///
/// Le champ `version` n'a l'air de rien aujourd'hui, mais c'est lui qui
/// permettra plus tard de faire évoluer le format sans perdre les réglages
/// déjà saisis par l'utilisateur.
struct LibraryStateFile: Codable, Sendable {
    struct Entry: Codable, Sendable {
        var id: TrackID
        var score: Int
        var isMuted: Bool
    }

    var version: Int = 1
    var entries: [Entry] = []
    var history: [TrackID] = []
}

/// Écriture disque sérialisée et hors du fil principal.
///
/// C'est un `actor` : les écritures sont donc forcément mises à la queue
/// leu leu, jamais concurrentes. Et l'écriture est *atomique* — le système
/// écrit d'abord un fichier temporaire puis le renomme. Si l'app est tuée
/// pendant la sauvegarde, l'ancien fichier reste intact : on ne se retrouve
/// jamais avec un fichier de réglages à moitié écrit, donc illisible.
private actor LibraryStateWriter {
    private let url: URL
    private let logger = Logger(subsystem: "com.example.Soundflow", category: "state")

    /// Numéro de la dernière version écrite.
    ///
    /// Les sauvegardes sont lancées depuis des tâches asynchrones, et rien ne
    /// garantit qu'elles arrivent ici dans l'ordre où elles ont été
    /// demandées. Sans ce garde-fou, une sauvegarde ancienne pourrait écraser
    /// une plus récente — l'utilisateur verrait son réglage « revenir tout
    /// seul ». On ignore donc simplement les versions périmées.
    private var lastWrittenRevision: UInt64 = 0

    init(url: URL) {
        self.url = url
    }

    func write(_ state: LibraryStateFile, revision: UInt64) {
        guard revision >= lastWrittenRevision else { return }
        lastWrittenRevision = revision
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: url, options: [.atomic])
        } catch {
            logger.error("Échec d'écriture de l'état: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Mémoire des réglages utilisateur : scores favoris, sourdines, historique
/// d'écoute.
///
/// Choix de stockage : un simple fichier JSON, pas de base de données.
/// Pourquoi ? Parce que les données sont minuscules (quelques dizaines
/// d'octets par morceau), qu'il n'y a aucune requête complexe à faire, et
/// qu'une base de données ajoute des modes de panne (migrations, corruption,
/// verrous) pour un bénéfice nul ici. Moins de pièces mobiles = moins de bugs.
@MainActor
@Observable
final class PreferencesStore {

    /// Nombre de titres conservés dans l'historique. Largement supérieur à la
    /// fenêtre utilisée par l'algorithme, pour que celle-ci soit toujours
    /// complète même après un redémarrage.
    static let historyLimit = 300

    private(set) var preferences: [TrackID: TrackPreferences] = [:]

    /// Historique d'écoute, **du plus récent au plus ancien**.
    private(set) var history: [TrackID] = []

    private let writer: LibraryStateWriter
    private let logger = Logger(subsystem: "com.example.Soundflow", category: "state")

    /// Incrémenté à chaque modification, pour ordonner les écritures disque.
    @ObservationIgnored private var revision: UInt64 = 0

    init(fileURL: URL? = nil) {
        let url = fileURL ?? PreferencesStore.defaultFileURL()
        self.writer = LibraryStateWriter(url: url)
        load(from: url)
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appending(path: "Soundflow", directoryHint: .isDirectory)
            .appending(path: "library-state.json")
    }

    // MARK: - Lecture

    func preferences(for id: TrackID) -> TrackPreferences {
        preferences[id] ?? .neutral
    }

    func score(for id: TrackID) -> Int {
        preferences(for: id).score
    }

    func isMuted(_ id: TrackID) -> Bool {
        preferences(for: id).isMuted
    }

    // MARK: - Écriture

    func setScore(_ score: Int, for id: TrackID) {
        var current = preferences(for: id)
        let clamped = TrackPreferences.clamp(score)
        guard current.score != clamped else { return }
        current.score = clamped
        apply(current, to: id)
    }

    /// Utilisé par les boutons « − » et « + » de la liste.
    func adjustScore(by delta: Int, for id: TrackID) {
        setScore(preferences(for: id).score + delta, for: id)
    }

    func setMuted(_ isMuted: Bool, for id: TrackID) {
        var current = preferences(for: id)
        guard current.isMuted != isMuted else { return }
        current.isMuted = isMuted
        apply(current, to: id)
    }

    func toggleMuted(_ id: TrackID) {
        setMuted(!isMuted(id), for: id)
    }

    /// Enregistre qu'un morceau vient d'être joué. C'est cette liste que
    /// l'algorithme de lecture aléatoire consulte pour éviter les répétitions.
    func recordPlay(of id: TrackID) {
        history.removeAll { $0 == id }
        history.insert(id, at: 0)
        if history.count > Self.historyLimit {
            history.removeLast(history.count - Self.historyLimit)
        }
        save()
    }

    /// Nettoie les réglages et l'historique des morceaux qui n'existent plus.
    /// Appelé après chaque rafraîchissement de la bibliothèque.
    func prune(keeping existing: Set<TrackID>) {
        let removedPreferences = preferences.keys.filter { !existing.contains($0) }
        let historyBefore = history.count
        history.removeAll { !existing.contains($0) }
        guard !removedPreferences.isEmpty || history.count != historyBefore else { return }
        for id in removedPreferences { preferences.removeValue(forKey: id) }
        save()
    }

    private func apply(_ value: TrackPreferences, to id: TrackID) {
        if value.isDefault {
            preferences.removeValue(forKey: id)
        } else {
            preferences[id] = value
        }
        save()
    }

    // MARK: - Persistance

    /// Sauvegarde immédiate, mais asynchrone : l'interface n'attend jamais le
    /// disque. Les mutations sont rares (un tap utilisateur, un changement de
    /// morceau) et le fichier est minuscule ; inutile de complexifier avec un
    /// mécanisme de report.
    func save() {
        revision += 1
        let snapshot = makeSnapshot()
        let currentRevision = revision
        Task { await writer.write(snapshot, revision: currentRevision) }
    }

    /// Sauvegarde à effectuer avant que l'app ne passe en arrière-plan.
    /// Contrairement à `save()`, celle-ci s'attend : l'appelant sait que le
    /// fichier est à jour quand elle rend la main.
    func flush() async {
        revision += 1
        await writer.write(makeSnapshot(), revision: revision)
    }

    private func makeSnapshot() -> LibraryStateFile {
        LibraryStateFile(
            version: 1,
            entries: preferences.map {
                LibraryStateFile.Entry(id: $0.key, score: $0.value.score, isMuted: $0.value.isMuted)
            },
            history: history
        )
    }

    private func load(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            let state = try JSONDecoder().decode(LibraryStateFile.self, from: data)
            var loaded: [TrackID: TrackPreferences] = [:]
            for entry in state.entries {
                let value = TrackPreferences(score: entry.score, isMuted: entry.isMuted)
                if !value.isDefault { loaded[entry.id] = value }
            }
            preferences = loaded
            history = Array(state.history.prefix(Self.historyLimit))
        } catch {
            // Un fichier illisible ne doit pas empêcher l'app de démarrer.
            // On repart sur des réglages neutres plutôt que de planter.
            logger.error("État illisible, réinitialisation: \(error.localizedDescription, privacy: .public)")
            preferences = [:]
            history = []
        }
    }
}
