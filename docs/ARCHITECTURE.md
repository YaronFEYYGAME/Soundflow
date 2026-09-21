# Architecture

## L'idée en une phrase

Le lecteur ne sait pas d'où viennent les fichiers, et le stockage ne sait pas
qu'il existe un lecteur. Entre les deux, un contrat : le protocole
`AudioSource`.

## Les quatre couches

```
┌──────────────────────────────────────────────┐
│  UI/            écrans SwiftUI               │
│                 LibraryView, NowPlayingView  │
└───────────────────┬──────────────────────────┘
                    │ lit et appelle
┌───────────────────┴──────────────────────────┐
│  Playback/      PlayerController             │
│                 AudioSessionController       │
│                 NowPlayingCenter             │
└───────────────────┬──────────────────────────┘
                    │ ne connaît QUE ce contrat
            ╔═══════╧════════╗
            ║  AudioSource   ║   ←── la frontière
            ╚═══════╤════════╝
┌───────────────────┴──────────────────────────┐
│  Data/          LocalAudioSource  (fichiers) │
│                 PreferencesStore  (réglages) │
│                 LibraryModel      (état)     │
└───────────────────┬──────────────────────────┘
                    │ manipule
┌───────────────────┴──────────────────────────┐
│  Domain/        Track, TrackID               │
│                 TrackPreferences             │
│                 SmartShuffle                 │
└──────────────────────────────────────────────┘
```

Règle de dépendance : **une couche ne connaît que celle du dessous.**
`Domain/` ne connaît personne — il n'importe même pas AVFoundation ni
SwiftUI. C'est ce qui permet de le tester en une fraction de seconde.

## La frontière : `AudioSource`

```swift
protocol AudioSource: Sendable {
    var id: String { get }
    var displayName: String { get }
    func loadTracks() async throws -> [Track]
    func playbackURL(for track: Track) async throws -> URL
    func artworkData(for track: Track) async -> Data?
}
```

Trois décisions y sont encodées :

**1. `Track` ne contient pas d'URL.**
Savoir où sont réellement les octets est l'affaire exclusive de la source.
Pour un fichier local c'est un chemin ; pour Dropbox ce sera peut-être une URL
signée valable dix minutes. Le lecteur demande l'URL *au moment de jouer*, et
se moque de comment elle a été obtenue.

**2. Tout est `async`.**
Lire un dossier local est instantané, interroger un serveur ne l'est pas.
Rendre le contrat asynchrone aujourd'hui coûte quelques `await` ; l'ajouter
plus tard coûterait une réécriture du lecteur et de l'interface.

**3. L'import est une capacité séparée.**

```swift
protocol ImportingAudioSource: AudioSource {
    var supportedContentTypes: [UTType] { get }
    func importTracks(from urls: [URL]) async -> (imported: [Track], failures: [AudioSourceError])
    func deleteTrack(_ track: Track) async throws
}
```

Une source en lecture seule (un dossier Dropbox partagé, par exemple) n'a pas
à faire semblant de savoir importer. L'interface teste simplement
`library.importingSource != nil` pour afficher ou masquer le bouton **+**.

## L'identifiant, pièce discrète mais centrale

```swift
TrackID(sourceID: "local", key: "Ma chanson.mp3")   // → "local:Ma chanson.mp3"
```

Les réglages de l'utilisateur (score, sourdine) et l'historique d'écoute sont
indexés par cet identifiant, **jamais par un chemin de fichier**. Conséquence
concrète : le jour où une source iCloud apparaît, les réglages existants
restent valides, et les deux sources cohabitent sans risque de collision
d'identifiants.

---

## Ajouter une source en ligne : la marche à suivre

Le travail se limite à trois points. Rien dans `Playback/`, `UI/` ou
`Domain/` n'a besoin de changer.

### 1. Écrire la source

```swift
actor CloudAudioSource: AudioSource {
    let id = "icloud"                 // ⚠️ ne doit JAMAIS changer ensuite
    let displayName = "iCloud Drive"

    func loadTracks() async throws -> [Track] {
        // Lister les fichiers distants, lire leurs métadonnées,
        // construire des Track avec TrackID(sourceID: id, key: <clé stable>)
    }

    func playbackURL(for track: Track) async throws -> URL {
        // Télécharger dans un cache local si nécessaire,
        // puis renvoyer l'URL du fichier mis en cache.
        // AVPlayer accepte aussi une URL https directe si le service
        // fournit un flux lisible.
    }
}
```

Le point délicat est le choix de la `key` : elle doit être **stable dans le
temps**, sinon l'utilisateur perdra ses scores au premier renommage. Un
identifiant fourni par le service (l'`id` d'un fichier Dropbox, par exemple)
est préférable à un nom de fichier.

### 2. Brancher la source

Une seule ligne à changer, dans `App/AppEnvironment.swift` :

```swift
let library = LibraryModel(source: CloudAudioSource())
```

### 3. (Optionnel) Gérer plusieurs sources à la fois

Écrire une `CompositeAudioSource` qui implémente elle-même `AudioSource` et
agrège plusieurs sources : `loadTracks()` concatène, et `playbackURL(for:)`
route vers la bonne source en lisant `track.id.sourceID`. Là encore, ni le
lecteur ni l'interface ne bougent.

---

## Où vivent les données

| Quoi | Où | Pourquoi |
|---|---|---|
| Fichiers audio | `Documents/` de l'app | Visible dans Fichiers et le Finder : dépôt par glisser-déposer, sans code |
| Scores, sourdines, historique | `Application Support/Soundflow/library-state.json` | Invisible de l'utilisateur, sauvegardé par iCloud Backup, jamais confondu avec la musique |

Le fichier d'état est écrit de façon **atomique** (fichier temporaire puis
renommage) et **numérotée** (une sauvegarde plus ancienne ne peut pas écraser
une plus récente). Si l'app est tuée en pleine écriture, l'ancien fichier
reste intact. Et s'il est malgré tout illisible, l'app démarre sur des
réglages neutres plutôt que de planter.
