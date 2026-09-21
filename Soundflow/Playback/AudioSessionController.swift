import AVFoundation
import Foundation
import os

/// Gère la « session audio » du système.
///
/// C'est la pièce la plus importante pour la stabilité en arrière-plan, et
/// celle qu'on oublie le plus souvent. Trois choses s'y jouent :
///
/// 1. **La catégorie `.playback`.** Elle dit à iOS : « cette app produit du
///    son, c'est sa raison d'être ». Sans elle, le son se coupe dès que
///    l'écran se verrouille, et le bouton silencieux de l'iPhone coupe la
///    musique. Avec elle, la lecture continue écran éteint — ce qui, combiné
///    au mode d'arrière-plan `audio` déclaré dans les réglages du projet, est
///    exactement l'usage visé (écoute prolongée au casque).
///
/// 2. **Les interruptions.** Un appel téléphonique, une alarme, Siri : iOS met
///    notre son en pause et nous prévient. Si on ne réagit pas, la musique ne
///    repart jamais. On reprend donc automatiquement quand le système nous
///    dit que c'est possible.
///
/// 3. **Les changements de sortie.** Quand on débranche le casque ou qu'on
///    range les AirPods, il faut mettre en pause. Sinon la musique se met à
///    jouer dans le haut-parleur en pleine rue — le bug le plus détesté de
///    tous les lecteurs audio.
@MainActor
final class AudioSessionController {

    /// Appelé quand le système demande de mettre en pause.
    var onShouldPause: (() -> Void)?
    /// Appelé quand le système autorise la reprise après une interruption.
    var onShouldResume: (() -> Void)?

    private let logger = Logger(subsystem: "com.example.Soundflow", category: "audio-session")
    private var isConfigured = false
    private var isActive = false
    // Lu par `deinit`, qui ne s'exécute pas forcément sur le fil principal.
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init() {
        registerObservers()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Prépare la session. Idempotent : appelable autant de fois qu'on veut.
    func configure() {
        guard !isConfigured else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: []
            )
            isConfigured = true
        } catch {
            logger.error("Configuration de la session impossible: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Active la session. On le fait au premier `play()` et pas au lancement :
    /// une app qui s'approprie la sortie audio sans rien jouer coupe la
    /// musique des autres apps pour rien.
    func activate() {
        configure()
        guard !isActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            isActive = true
        } catch {
            logger.error("Activation de la session impossible: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Notifications système

    private func registerObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        observers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                let info = notification.userInfo
                Task { @MainActor in self?.handleInterruption(info) }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                let info = notification.userInfo
                Task { @MainActor in self?.handleRouteChange(info) }
            }
        )

        // Cas rare mais réel : une autre app (ou un crash de service système)
        // peut réinitialiser le moteur audio. On se réactive alors.
        observers.append(
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isConfigured = false
                    self.isActive = false
                    self.configure()
                    self.onShouldPause?()
                }
            }
        )
    }

    private func handleInterruption(_ userInfo: [AnyHashable: Any]?) {
        guard
            let rawType = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        switch type {
        case .began:
            // iOS a déjà coupé le son ; on se contente de synchroniser l'état
            // affiché pour que le bouton lecture soit cohérent.
            onShouldPause?()
        case .ended:
            let rawOptions = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            if options.contains(.shouldResume) {
                activate()
                onShouldResume?()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ userInfo: [AnyHashable: Any]?) {
        guard
            let rawReason = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason)
        else { return }

        if reason == .oldDeviceUnavailable {
            // Casque débranché / AirPods retirés.
            onShouldPause?()
        }
    }
}
