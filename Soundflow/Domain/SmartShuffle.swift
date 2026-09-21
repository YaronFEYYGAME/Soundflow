import Foundation

/// Réglages de l'algorithme de lecture aléatoire.
///
/// Les valeurs par défaut sont volontairement conservatrices : mieux vaut une
/// aléatoire un peu prévisible qu'une aléatoire qui répète.
struct ShuffleConfiguration: Sendable, Equatable {
    /// Part de la bibliothèque interdite de rejeu immédiat.
    /// 0,4 signifie : après avoir écouté un morceau, il ne peut pas revenir
    /// avant que ~40 % de la bibliothèque soit passée.
    var cooldownFraction: Double = 0.4

    /// Plafond absolu de cette interdiction stricte. Sur une bibliothèque de
    /// 2 000 titres, bloquer 800 morceaux serait inutile et coûteux.
    var maximumHardCooldown: Int = 30

    /// Au-delà de l'interdiction stricte, les morceaux récemment joués restent
    /// pénalisés (moins probables) pendant encore `softWindowMultiplier` fois
    /// la fenêtre stricte. C'est ce qui donne l'impression de « ça ne tourne
    /// pas en rond » sans jamais bloquer complètement un titre.
    var softWindowMultiplier: Double = 2.5

    /// Pénalité minimale appliquée au morceau juste sorti de la fenêtre
    /// stricte (0,2 = cinq fois moins probable qu'un morceau oublié depuis
    /// longtemps).
    var minimumRecencyFactor: Double = 0.2

    static let `default` = ShuffleConfiguration()
}

/// Sélection pseudo-aléatoire pondérée d'un morceau.
///
/// Ce type est une **structure pure** : aucune dépendance au système de
/// fichiers, à l'audio ou à l'interface. Il prend des données en entrée et
/// renvoie un identifiant. C'est ce qui permet de le tester entièrement et de
/// garantir, par des tests, les deux promesses faites à l'utilisateur :
/// jamais deux fois le même morceau d'affilée, et pas de répétition rapprochée.
struct SmartShuffle: Sendable {
    var configuration: ShuffleConfiguration

    init(configuration: ShuffleConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Poids lié au score favori

    /// Traduit un score de -2…+2 en un multiplicateur de probabilité.
    ///
    /// Règle retenue, volontairement simple et symétrique :
    /// - score  0 → poids 1   (fréquence normale)
    /// - score +1 → poids 2   (deux fois plus probable)
    /// - score +2 → poids 3   (trois fois plus probable)
    /// - score -1 → poids 1/2 (deux fois moins probable)
    /// - score -2 → poids 1/3 (trois fois moins probable)
    ///
    /// L'augmentation est donc bien proportionnelle au score, et un score
    /// négatif raréfie le morceau sans jamais l'exclure — l'exclusion totale,
    /// c'est le rôle de la sourdine, qui est un réglage distinct et explicite.
    static func weight(forScore score: Int) -> Double {
        let clamped = TrackPreferences.clamp(score)
        return clamped >= 0 ? Double(clamped + 1) : 1.0 / Double(1 - clamped)
    }

    // MARK: - Sélection

    /// Choisit le prochain morceau.
    ///
    /// - Parameters:
    ///   - candidates: tous les morceaux de la bibliothèque.
    ///   - preferences: réglages connus, indexés par identifiant. Un morceau
    ///     absent du dictionnaire est simplement neutre.
    ///   - history: morceaux récemment joués, **du plus récent au plus ancien**.
    ///   - generator: source d'aléa, injectée pour rendre les tests déterministes.
    /// - Returns: l'identifiant choisi, ou `nil` si rien n'est jouable.
    func pickNext<G: RandomNumberGenerator>(
        from candidates: [TrackID],
        preferences: [TrackID: TrackPreferences],
        history: [TrackID],
        using generator: inout G
    ) -> TrackID? {
        // Étape 1 — la sourdine est un filtre dur, appliqué en premier.
        let eligible = candidates.filter { !(preferences[$0]?.isMuted ?? false) }
        guard !eligible.isEmpty else { return nil }
        guard eligible.count > 1 else { return eligible[0] }

        // Étape 2 — fenêtre d'interdiction stricte.
        // On ne bloque jamais la totalité de la bibliothèque : il reste
        // toujours au moins un morceau disponible.
        let hardCooldown = hardCooldownSize(eligibleCount: eligible.count)
        let recentlyPlayed = Set(history.prefix(hardCooldown))

        var pool = eligible.filter { !recentlyPlayed.contains($0) }
        if pool.isEmpty {
            // Cas limite (bibliothèque minuscule, ou historique saturé de
            // morceaux depuis mis en sourdine) : on relâche la contrainte,
            // mais on conserve la promesse la plus importante — ne jamais
            // rejouer immédiatement le morceau en cours.
            let lastPlayed = history.first
            pool = eligible.filter { $0 != lastPlayed }
            if pool.isEmpty { pool = eligible }
        }

        // Étape 3 — position dans l'historique, pour la pénalité douce.
        var historyPosition: [TrackID: Int] = [:]
        let softWindow = softWindowSize(hardCooldown: hardCooldown)
        for (index, id) in history.prefix(softWindow).enumerated() {
            if historyPosition[id] == nil { historyPosition[id] = index }
        }

        // Étape 4 — poids final de chaque candidat.
        var weights = [Double](repeating: 0, count: pool.count)
        var total = 0.0
        for (index, id) in pool.enumerated() {
            var weight = SmartShuffle.weight(forScore: preferences[id]?.score ?? 0)
            if let position = historyPosition[id] {
                weight *= recencyFactor(position: position, softWindow: softWindow)
            }
            // Garde-fou : un poids nul ou non fini rendrait la sélection
            // impossible. On borne par le bas plutôt que de risquer un
            // comportement indéfini.
            if !weight.isFinite || weight <= 0 { weight = 0.0001 }
            weights[index] = weight
            total += weight
        }

        guard total > 0, total.isFinite else {
            return pool.randomElement(using: &generator)
        }

        // Étape 5 — tirage pondéré (méthode de la roue de loterie).
        let draw = Double.random(in: 0..<total, using: &generator)
        var cursor = 0.0
        for (index, weight) in weights.enumerated() {
            cursor += weight
            if draw < cursor { return pool[index] }
        }
        // Filet de sécurité contre les arrondis flottants.
        return pool.last
    }

    /// Variante utilisant l'aléa du système. C'est celle qu'appelle l'app.
    func pickNext(
        from candidates: [TrackID],
        preferences: [TrackID: TrackPreferences],
        history: [TrackID]
    ) -> TrackID? {
        var generator = SystemRandomNumberGenerator()
        return pickNext(
            from: candidates,
            preferences: preferences,
            history: history,
            using: &generator
        )
    }

    // MARK: - Détails internes (exposés pour les tests)

    /// Nombre de morceaux strictement interdits de rejeu.
    /// Toujours compris entre 1 et `eligibleCount - 1`.
    func hardCooldownSize(eligibleCount: Int) -> Int {
        guard eligibleCount > 1 else { return 0 }
        let proportional = Int((Double(eligibleCount) * configuration.cooldownFraction).rounded())
        let capped = min(proportional, configuration.maximumHardCooldown)
        return min(max(capped, 1), eligibleCount - 1)
    }

    /// Taille de la fenêtre de pénalité douce.
    func softWindowSize(hardCooldown: Int) -> Int {
        guard hardCooldown > 0 else { return 0 }
        let size = Int((Double(hardCooldown) * configuration.softWindowMultiplier).rounded())
        return max(size, hardCooldown + 1)
    }

    /// Facteur multiplicateur lié à l'ancienneté d'écoute.
    ///
    /// `position` 0 = joué à l'instant. Plus la position augmente, plus le
    /// facteur se rapproche de 1 (plus aucune pénalité).
    func recencyFactor(position: Int, softWindow: Int) -> Double {
        guard softWindow > 0, position < softWindow else { return 1 }
        let progress = Double(position + 1) / Double(softWindow)
        let minimum = configuration.minimumRecencyFactor
        return minimum + (1 - minimum) * progress
    }
}
