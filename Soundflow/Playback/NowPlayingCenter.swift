import Foundation
import MediaPlayer

/// Renseigne l'écran verrouillé, le centre de contrôle, les AirPods et
/// CarPlay ; et reçoit en retour les commandes de ces surfaces.
///
/// Pour une app dont l'usage principal est « écran éteint, casque sur les
/// oreilles », ce n'est pas un luxe : sans ça, l'utilisateur ne peut ni voir
/// ce qui joue, ni passer au titre suivant depuis les boutons de son casque.
@MainActor
final class NowPlayingCenter {

    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)?

    private var isConfigured = false

    /// Branche les commandes. Idempotent.
    ///
    /// Note : `MPRemoteCommandCenter` délivre ses événements sur le fil
    /// principal. Les gestionnaires ci-dessous peuvent donc appeler
    /// directement le lecteur, sans saut de contexte — ce qui est important,
    /// car un appui sur le bouton du casque doit répondre immédiatement.
    func activateRemoteCommands() {
        guard !isConfigured else { return }
        isConfigured = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.onPlay?()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.onPause?()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.onTogglePlayPause?()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.onNext?()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.onPrevious?()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard
                let self,
                let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            self.onSeek?(event.positionTime)
            return .success
        }

        // Commandes explicitement désactivées : elles n'ont pas de sens ici
        // et, laissées actives, elles affichent des boutons inertes sur
        // l'écran verrouillé.
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
        center.changeRepeatModeCommand.isEnabled = false
        center.changeShuffleModeCommand.isEnabled = false
        center.likeCommand.isEnabled = false
        center.dislikeCommand.isEnabled = false
        center.ratingCommand.isEnabled = false
    }

    /// Met à jour les informations affichées.
    func update(
        track: Track?,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        artwork: MPMediaItemArtwork?
    ) {
        guard let track else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artistDisplayName
        if let album = track.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, currentTime)
        // Le « taux » sert au système à animer la progression tout seul entre
        // deux mises à jour : 1 quand ça joue, 0 quand c'est en pause.
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
}
