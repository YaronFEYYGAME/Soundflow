import Foundation

/// File d'attente « à suivre » : les morceaux que l'utilisateur a demandé
/// d'entendre après le morceau en cours, dans l'ordre.
///
/// Comme `SmartShuffle`, c'est une structure pure : aucune dépendance au
/// lecteur ni à l'interface. Toutes ses règles se testent donc directement.
///
/// Chaque entrée a son propre identifiant, distinct de celui du morceau : on
/// peut ainsi mettre deux fois le même titre dans la file, et en retirer un
/// seul exemplaire sans toucher à l'autre.
struct PlaybackQueue: Equatable, Sendable {

    struct Entry: Identifiable, Hashable, Sendable {
        let id: UUID
        let trackID: TrackID

        init(id: UUID = UUID(), trackID: TrackID) {
            self.id = id
            self.trackID = trackID
        }
    }

    private(set) var entries: [Entry] = []

    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }

    /// Ajoute un morceau en fin de file et renvoie sa position (à partir de 1),
    /// pour pouvoir l'annoncer à l'utilisateur.
    @discardableResult
    mutating func enqueue(_ trackID: TrackID) -> Int {
        entries.append(Entry(trackID: trackID))
        return entries.count
    }

    /// Retire et renvoie le prochain morceau **encore disponible**.
    ///
    /// Un morceau peut avoir été supprimé de la bibliothèque entre le moment
    /// où il a été mis en file et celui où son tour arrive. Plutôt que de
    /// tenter de le lire (et d'échouer), on l'écarte silencieusement et on
    /// passe au suivant.
    ///
    /// - Parameter available: identifiants présents dans la bibliothèque.
    ///   Un ensemble plutôt qu'une fonction : la file reste ainsi une
    ///   structure de données pure, sans rien à appeler hors d'elle-même.
    mutating func dequeueNext(availableIn available: Set<TrackID>) -> TrackID? {
        while !entries.isEmpty {
            let entry = entries.removeFirst()
            if available.contains(entry.trackID) { return entry.trackID }
        }
        return nil
    }

    /// Retire une entrée précise et renvoie son morceau (tap sur une ligne de
    /// la file : « joue celui-là maintenant »).
    mutating func remove(id: UUID) -> TrackID? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return entries.remove(at: index).trackID
    }

    /// Suppression par positions, telle que la fournit un balayage dans une
    /// liste SwiftUI.
    mutating func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) where entries.indices.contains(index) {
            entries.remove(at: index)
        }
    }

    /// Déplacement par glisser-déposer.
    ///
    /// Sémantique identique à celle de SwiftUI : `destination` désigne la
    /// position d'insertion **dans la liste d'origine**, avant retrait des
    /// éléments déplacés. Réimplémentée ici pour que le domaine ne dépende pas
    /// de SwiftUI — et pour pouvoir la tester.
    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let valid = offsets.filter { entries.indices.contains($0) }
        guard !valid.isEmpty else { return }
        let moving = valid.sorted().map { entries[$0] }
        var remaining: [Entry] = []
        remaining.reserveCapacity(entries.count)
        for (index, entry) in entries.enumerated() where !valid.contains(index) {
            remaining.append(entry)
        }
        let shift = valid.filter { $0 < destination }.count
        let insertion = min(max(destination - shift, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: insertion)
        entries = remaining
    }

    mutating func removeAll() {
        entries.removeAll()
    }
}
