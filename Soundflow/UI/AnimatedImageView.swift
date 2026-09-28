import ImageIO
import SwiftUI
import UIKit
import os

/// Affiche un GIF animé.
///
/// SwiftUI ne sait pas animer un GIF : `Image` n'en montre que la première
/// image. On passe donc par UIKit, avec une fonction d'ImageIO,
/// `CGAnimateImageAtURLWithBlock`, choisie pour une raison précise : elle
/// décode les images **une par une, au fil de l'animation**. L'approche
/// habituelle (tout décoder d'avance) coûte des centaines de mégaoctets pour un
/// GIF un peu long — de quoi faire tuer l'app par iOS en pleine écoute.
///
/// L'animation s'arrête dès que `isPaused` passe à `true` (app en
/// arrière-plan) : décoder des images que personne ne regarde, pendant des
/// heures d'écoute écran éteint, viderait la batterie pour rien.
struct AnimatedImageView: UIViewRepresentable {
    let url: URL
    let isPaused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        // Conteneur sans taille propre : c'est SwiftUI qui décide de la taille,
        // pas les dimensions du GIF.
        let container = UIView()
        container.clipsToBounds = true

        let imageView = UIImageView(frame: container.bounds)
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        container.addSubview(imageView)

        context.coordinator.imageView = imageView
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(url: url, isPaused: isPaused)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    // MARK: - Coordinateur

    @MainActor
    final class Coordinator {
        weak var imageView: UIImageView?

        private var currentURL: URL?
        private var session: AnimationSession?

        /// Appelé à chaque rafraîchissement de la vue SwiftUI — donc souvent,
        /// puisque l'écran de lecture se met à jour deux fois par seconde. On
        /// ne relance l'animation que si quelque chose a réellement changé.
        func update(url: URL, isPaused: Bool) {
            if isPaused {
                stop()
                if currentURL != url {
                    currentURL = url
                    showFirstFrame(of: url)
                }
                return
            }
            if url != currentURL || session == nil {
                stop()
                start(url)
            }
        }

        func stop() {
            session?.stop()
            session = nil
        }

        private func start(_ url: URL) {
            currentURL = url
            let session = AnimationSession()
            self.session = session
            let target = imageView

            let status = CGAnimateImageAtURLWithBlock(url as CFURL, nil) { [weak target] _, frame, stop in
                if session.isStopped {
                    stop.pointee = true
                    return
                }
                let image = UIImage(cgImage: frame)
                Task { @MainActor in
                    guard !session.isStopped else { return }
                    target?.image = image
                }
            }

            if status != noErr {
                // Fichier illisible comme animation : on se contente d'une
                // image fixe plutôt que d'afficher du vide.
                self.session = nil
                showFirstFrame(of: url)
            }
        }

        private func showFirstFrame(of url: URL) {
            let target = imageView
            Task {
                let image = await Task.detached(priority: .userInitiated) {
                    ImageProcessing.downsampledImage(at: url, maxPixelSize: 1_024)
                }.value
                target?.image = image
            }
        }
    }
}

/// Drapeau d'arrêt partagé entre l'interface et le fil de décodage d'ImageIO.
///
/// Protégé par un verrou : il est écrit depuis le fil principal et lu depuis
/// celui d'ImageIO. Sans verrou, ce serait une lecture concurrente non
/// synchronisée — le genre de bug qui ne se manifeste qu'une fois sur mille.
final class AnimationSession: Sendable {
    private let stopped = OSAllocatedUnfairLock(initialState: false)

    var isStopped: Bool {
        stopped.withLock { $0 }
    }

    func stop() {
        stopped.withLock { $0 = true }
    }
}
