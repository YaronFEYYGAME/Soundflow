import Foundation

/// Réglages de l'utilisateur pour un morceau donné.
///
/// Ces réglages sont indépendants du fichier lui-même : ils vivent dans le
/// stockage de l'application et survivent à une réinstallation des fichiers,
/// voire au passage du morceau d'une source locale à une source distante
/// (tant que la clé reste la même).
struct TrackPreferences: Hashable, Codable, Sendable {
    /// Score favori, de -2 à +2. 0 = neutre.
    var score: Int
    /// Mis en sourdine : exclu de la lecture aléatoire, mais toujours jouable
    /// manuellement.
    var isMuted: Bool

    static let neutral = TrackPreferences(score: 0, isMuted: false)

    /// Bornes du score. Centralisées ici pour que l'interface et l'algorithme
    /// ne puissent pas diverger.
    static let scoreRange = -2...2

    init(score: Int = 0, isMuted: Bool = false) {
        self.score = TrackPreferences.clamp(score)
        self.isMuted = isMuted
    }

    static func clamp(_ score: Int) -> Int {
        min(max(score, scoreRange.lowerBound), scoreRange.upperBound)
    }

    /// `true` si l'entrée n'apporte aucune information : on évite alors de
    /// l'écrire sur disque, ce qui garde le fichier d'état petit.
    var isDefault: Bool { self == .neutral }
}

extension TrackPreferences {
    /// Libellé court affiché à côté du score (accessibilité + lisibilité).
    var scoreLabel: String {
        switch score {
        case 2: return "Beaucoup plus souvent"
        case 1: return "Plus souvent"
        case 0: return "Fréquence normale"
        case -1: return "Moins souvent"
        default: return "Beaucoup moins souvent"
        }
    }
}
