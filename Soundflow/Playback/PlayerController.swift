import AVFoundation
import Foundation
import MediaPlayer
import Observation
import UIKit
import os

/// Orchestre la lecture : quoi jouer, quand, et quoi faire quand ça se passe mal.
///
/// Choix du moteur audio : **`AVPlayer`**, et non `AVAudioPlayer`.
/// `AVAudioPlayer` est un peu plus simple, mais il ne sait lire que des
/// fichiers déjà entièrement présents sur le disque. `AVPlayer` lit
/// indifféremment une URL locale et une URL réseau, avec mise en mémoire
/// tampon. Comme l'objectif annoncé est d'ajouter plus tard une source en
/// ligne, choisir `AVPlayer` dès maintenant évite de réécrire toute la
/// lecture à ce moment-là. Le surcoût de complexité aujourd'hui est faible.
@MainActor
@Observable
final class PlayerController {

    // MARK: - État exposé à l'interface

    private(set) var currentTrack: Track?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var artworkImage: UIImage?

    /// Message d'erreur passager (fichier illisible, etc.).
    var lastError: String?

    /// Lecture aléatoire intelligente activée. Quand elle est désactivée, la
    /// lecture suit simplement l'ordre de la liste.
    var isShuffleEnabled = true

    /// L'utilisateur est en train de déplacer le curseur : on suspend alors
    /// les mises à jour automatiques de position pour éviter que le curseur
    /// « saute » sous le doigt.
    var isScrubbing = false

    // MARK: - Dépendances

    private let library: LibraryModel
    private let store: PreferencesStore
    private let shuffle: SmartShuffle
    private let session = AudioSessionController()
    private let nowPlaying = NowPlayingCenter()
    private let logger = Logger(subsystem: "com.example.Soundflow", category: "player")

    // MARK: - Interne

    // `nonisolated(unsafe)` : ces deux membres sont lus par `deinit`, qui ne
    // s'exécute pas forcément sur le fil principal. Ils ne sont jamais
    // manipulés depuis un autre fil en pratique — l'annotation dit juste au
    // compilateur que l'on en prend la responsabilité.
    // `@ObservationIgnored` sur toute la mécanique interne : SwiftUI n'a
    // aucune raison de redessiner l'écran parce qu'un jeton d'observation a
    // changé. On réserve le suivi automatique aux propriétés réellement
    // affichées, déclarées plus haut.
    nonisolated(unsafe) private let player = AVPlayer()
    @ObservationIgnored nonisolated(unsafe) private var timeObserverToken: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var rateObservation: NSKeyValueObservation?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var failureObserver: NSObjectProtocol?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?

    /// Pile de navigation arrière/avant, indépendante de l'historique
    /// d'écoute utilisé par l'algorithme aléatoire.
    @ObservationIgnored private var backStack: [TrackID] = []
    @ObservationIgnored private var forwardStack: [TrackID] = []

    /// Compteur de sécurité : si plusieurs fichiers d'affilée sont illisibles,
    /// on arrête au lieu d'enchaîner les échecs à l'infini (ce qui viderait
    /// la batterie et donnerait l'impression d'un plantage).
    @ObservationIgnored private var consecutiveFailures = 0

    init(
        library: LibraryModel,
        store: PreferencesStore,
        shuffle: SmartShuffle = SmartShuffle()
    ) {
        self.library = library
        self.store = store
        self.shuffle = shuffle

        // Pour un fichier local, attendre un remplissage de tampon n'a aucun
        // intérêt et ajoute un délai perceptible avant le premier son.
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .pause

        session.configure()
        wireSessionCallbacks()
        wireRemoteCommands()
        observePlayer()
    }

    deinit {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
    }

    // MARK: - Actions publiques

    /// Lance un morceau choisi explicitement par l'utilisateur.
    /// Un morceau en sourdine reste parfaitement jouable ainsi : la sourdine
    /// ne concerne que le tirage aléatoire.
    func play(_ track: Track) {
        if let current = currentTrack, current.id != track.id {
            backStack.append(current.id)
        }
        forwardStack.removeAll()
        start(track, autoPlay: true)
    }

    /// Bouton lecture/pause.
    func togglePlayPause() {
        guard currentTrack != nil else {
            startPlaybackFromScratch()
            return
        }
        if isPlaying {
            player.pause()
        } else {
            session.activate()
            player.play()
        }
    }

    func pause() {
        player.pause()
    }

    func resume() {
        guard currentTrack != nil else {
            startPlaybackFromScratch()
            return
        }
        session.activate()
        player.play()
    }

    /// Morceau suivant.
    func playNext() {
        consecutiveFailures = 0
        advance(autoPlay: true)
    }

    /// Morceau précédent.
    ///
    /// Comportement classique et attendu : si on est à plus de 3 secondes du
    /// début, on revient au début du morceau en cours ; sinon on remonte
    /// vraiment d'un titre.
    func playPrevious() {
        if currentTime > 3, currentTrack != nil {
            seek(to: 0)
            return
        }
        guard let previousID = backStack.popLast(), let track = library.track(with: previousID) else {
            seek(to: 0)
            return
        }
        if let current = currentTrack {
            forwardStack.append(current.id)
        }
        start(track, autoPlay: true)
    }

    func seek(to seconds: TimeInterval) {
        let clamped = min(max(0, seconds), duration > 0 ? duration : seconds)
        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        // `toleranceBefore/After = .zero` : on va exactement où l'utilisateur
        // a demandé, pas « quelque part par là ».
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = clamped
                self?.refreshNowPlaying()
            }
        }
    }

    /// Démarre l'écoute quand rien ne joue encore (bouton « Lecture aléatoire »).
    func startPlaybackFromScratch() {
        guard !library.tracks.isEmpty else { return }
        consecutiveFailures = 0
        guard let track = nextTrackForShuffle() else {
            // Tous les morceaux sont en sourdine : on le dit, plutôt que de
            // ne rien faire silencieusement — un bouton sans effet visible
            // est toujours interprété comme un bug.
            lastError = "Tous les morceaux sont en sourdine. Réactivez-en au moins un."
            return
        }
        start(track, autoPlay: true)
    }

    /// Appelé quand la bibliothèque change : si le morceau en cours a disparu,
    /// on s'arrête proprement au lieu de jouer dans le vide.
    func libraryDidChange() {
        guard let currentTrack else { return }
        if library.track(with: currentTrack.id) == nil {
            stop()
        }
    }

    func stop() {
        loadTask?.cancel()
        artworkTask?.cancel()
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentTrack = nil
        currentTime = 0
        duration = 0
        artworkImage = nil
        isPlaying = false
        nowPlaying.clear()
    }

    // MARK: - Sélection du morceau suivant

    private func advance(autoPlay: Bool) {
        // Priorité à la pile « avant » : si l'utilisateur est revenu en
        // arrière, « suivant » doit refaire le chemin inverse, pas tirer un
        // nouveau morceau au hasard.
        if let forwardID = forwardStack.popLast(), let track = library.track(with: forwardID) {
            if let current = currentTrack { backStack.append(current.id) }
            start(track, autoPlay: autoPlay)
            return
        }

        let next: Track?
        if isShuffleEnabled {
            next = nextTrackForShuffle()
        } else {
            next = nextTrackInOrder()
        }

        guard let next else {
            stop()
            return
        }

        if let current = currentTrack { backStack.append(current.id) }
        start(next, autoPlay: autoPlay)
    }

    private func nextTrackForShuffle() -> Track? {
        let candidates = library.tracks.map(\.id)
        guard !candidates.isEmpty else { return nil }

        // On place le morceau en cours en tête de l'historique transmis à
        // l'algorithme : c'est ce qui garantit qu'il ne peut pas être
        // retiré immédiatement.
        var history = store.history
        if let currentID = currentTrack?.id {
            history.removeAll { $0 == currentID }
            history.insert(currentID, at: 0)
        }

        let picked = shuffle.pickNext(
            from: candidates,
            preferences: store.preferences,
            history: history
        )
        guard let picked else { return nil }
        return library.track(with: picked)
    }

    private func nextTrackInOrder() -> Track? {
        let tracks = library.tracks
        guard !tracks.isEmpty else { return nil }
        guard
            let currentID = currentTrack?.id,
            let index = tracks.firstIndex(where: { $0.id == currentID })
        else {
            return tracks.first
        }
        return tracks[(index + 1) % tracks.count]
    }

    // MARK: - Chargement et lecture

    private func start(_ track: Track, autoPlay: Bool) {
        loadTask?.cancel()
        artworkTask?.cancel()

        currentTrack = track
        currentTime = 0
        duration = track.duration ?? 0
        artworkImage = nil
        store.recordPlay(of: track.id)
        refreshNowPlaying()

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await self.library.source.playbackURL(for: track)
                if Task.isCancelled { return }

                let asset = AVURLAsset(url: url)
                let item = AVPlayerItem(asset: asset)
                self.observeItem(item)
                self.player.replaceCurrentItem(with: item)

                if autoPlay {
                    self.session.activate()
                    self.player.play()
                }
                self.loadArtwork(for: track)
            } catch {
                if Task.isCancelled { return }
                self.handleFailure(for: track, message: error.localizedDescription)
            }
        }
    }

    private func loadArtwork(for track: Track) {
        artworkTask = Task { [weak self] in
            guard let self else { return }
            let data = await self.library.source.artworkData(for: track)
            if Task.isCancelled { return }
            guard self.currentTrack?.id == track.id else { return }
            if let data, let image = UIImage(data: data) {
                self.artworkImage = image
            }
            self.refreshNowPlaying()
        }
    }

    /// Gestion centralisée des fichiers qui ne se lisent pas.
    ///
    /// Règle : on ne plante jamais et on ne reste jamais bloqué. On passe au
    /// suivant, et on ne s'acharne pas si tout échoue.
    private func handleFailure(for track: Track, message: String) {
        logger.error("Lecture impossible (\(track.title, privacy: .public)): \(message, privacy: .public)")
        consecutiveFailures += 1
        lastError = "Impossible de lire « \(track.title) »."

        let limit = min(5, max(1, library.tracks.count))
        guard consecutiveFailures < limit else {
            consecutiveFailures = 0
            stop()
            lastError = "Plusieurs fichiers sont illisibles. Lecture arrêtée."
            return
        }
        advance(autoPlay: true)
    }

    // MARK: - Observation du lecteur

    private func observePlayer() {
        // Position de lecture, deux fois par seconde : assez fluide pour
        // l'affichage, assez rare pour ne pas réveiller le processeur sans
        // arrêt pendant une écoute écran éteint.
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self, !self.isScrubbing else { return }
                let seconds = CMTimeGetSeconds(time)
                if seconds.isFinite { self.currentTime = max(0, seconds) }
            }
        }

        // `timeControlStatus` est la source de vérité sur « est-ce que ça
        // joue ? ». S'appuyer dessus plutôt que sur un drapeau maison évite
        // les désynchronisations entre le bouton affiché et la réalité.
        rateObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let playing = player.timeControlStatus == .playing
            Task { @MainActor in
                guard let self else { return }
                if self.isPlaying != playing {
                    self.isPlaying = playing
                }
                if playing { self.consecutiveFailures = 0 }
                self.refreshNowPlaying()
            }
        }
    }

    private func observeItem(_ item: AVPlayerItem) {
        statusObservation?.invalidate()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            let errorMessage = item.error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    let seconds = CMTimeGetSeconds(item.duration)
                    if seconds.isFinite, seconds > 0 { self.duration = seconds }
                    self.refreshNowPlaying()
                case .failed:
                    guard let track = self.currentTrack else { return }
                    self.handleFailure(for: track, message: errorMessage ?? "erreur inconnue")
                default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.consecutiveFailures = 0
                self?.advance(autoPlay: true)
            }
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor in
                guard let self, let track = self.currentTrack else { return }
                self.handleFailure(for: track, message: error?.localizedDescription ?? "lecture interrompue")
            }
        }
    }

    // MARK: - Branchements

    private func wireSessionCallbacks() {
        session.onShouldPause = { [weak self] in
            self?.player.pause()
        }
        session.onShouldResume = { [weak self] in
            self?.player.play()
        }
        session.onActivationFailed = { [weak self] message in
            self?.lastError = "Le son ne peut pas démarrer : \(message)"
        }
    }

    private func wireRemoteCommands() {
        nowPlaying.onPlay = { [weak self] in self?.resume() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onTogglePlayPause = { [weak self] in self?.togglePlayPause() }
        nowPlaying.onNext = { [weak self] in self?.playNext() }
        nowPlaying.onPrevious = { [weak self] in self?.playPrevious() }
        nowPlaying.onSeek = { [weak self] position in self?.seek(to: position) }
        nowPlaying.activateRemoteCommands()
    }

    private func refreshNowPlaying() {
        var artwork: MPMediaItemArtwork?
        if let image = artworkImage {
            artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        nowPlaying.update(
            track: currentTrack,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            artwork: artwork
        )
    }
}

// MARK: - Confort d'affichage

extension PlayerController {
    /// Progression entre 0 et 1, utilisable directement par un `Slider`.
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    var remainingTime: TimeInterval {
        max(0, duration - currentTime)
    }
}

/// Formatage `m:ss` / `h:mm:ss`, partagé par tous les écrans.
enum TimeFormatter {
    static func string(from seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
