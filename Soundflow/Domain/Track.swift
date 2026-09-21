import Foundation

/// Identifiant unique et stable d'un morceau.
///
/// Il est volontairement composé de deux parties :
/// - `sourceID` : d'où vient le morceau (`"local"` aujourd'hui, `"icloud"` ou
///   `"dropbox"` demain) ;
/// - `key` : la clé du morceau à l'intérieur de cette source (ici, le nom de
///   fichier).
///
/// Conséquence importante : les préférences de l'utilisateur (score favori,
/// mise en sourdine) sont attachées à cet identifiant, pas à un chemin de
/// fichier. Ajouter une source distante plus tard n'invalide donc rien de ce
/// qui a déjà été enregistré.
struct TrackID: Hashable, Codable, Sendable, CustomStringConvertible {
    /// Représentation texte canonique, de la forme `"local:Ma chanson.mp3"`.
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(sourceID: String, key: String) {
        self.rawValue = "\(sourceID):\(key)"
    }

    /// Partie avant le premier `:`.
    var sourceID: String {
        guard let index = rawValue.firstIndex(of: ":") else { return rawValue }
        return String(rawValue[rawValue.startIndex..<index])
    }

    /// Tout ce qui suit le premier `:`. Le nom de fichier peut lui-même
    /// contenir des `:`, d'où le découpage sur le *premier* séparateur
    /// seulement.
    var key: String {
        guard let index = rawValue.firstIndex(of: ":") else { return "" }
        return String(rawValue[rawValue.index(after: index)...])
    }

    var description: String { rawValue }

    // Encodage volontairement explicite : un `TrackID` est une simple chaîne
    // dans le JSON enregistré sur disque, ce qui rend le fichier lisible et
    // facile à faire évoluer.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Un morceau, tel que l'application le connaît.
///
/// Remarque d'architecture : `Track` ne contient **pas** d'URL. Savoir où se
/// trouvent réellement les octets audio est la responsabilité exclusive de la
/// source (`AudioSource`). Pour un fichier local c'est un chemin sur le
/// disque ; pour une source distante ce sera peut-être une URL signée valable
/// dix minutes. Le reste de l'application n'a pas à connaître la différence.
struct Track: Identifiable, Hashable, Sendable {
    let id: TrackID
    var title: String
    var artist: String?
    var album: String?
    var duration: TimeInterval?
    var addedAt: Date

    init(
        id: TrackID,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        duration: TimeInterval? = nil,
        addedAt: Date = .distantPast
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.addedAt = addedAt
    }

    /// Libellé d'artiste prêt à afficher, jamais vide.
    var artistDisplayName: String {
        guard let artist, !artist.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Artiste inconnu"
        }
        return artist
    }
}
