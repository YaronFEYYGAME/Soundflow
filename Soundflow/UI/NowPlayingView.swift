import SwiftUI

/// Écran de lecture complet, présenté en feuille depuis la barre de lecture.
///
/// Tout ce qui compte tient sur un écran, sans défilement : pochette, titre,
/// position, transport, et — surtout — les deux réglages demandés (score
/// favori et sourdine) directement accessibles, pas enfouis dans un menu.
struct NowPlayingView: View {
    @Environment(PlayerController.self) private var player
    @Environment(PreferencesStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var scrubPosition: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let track = player.currentTrack {
                    artwork
                        .frame(maxWidth: .infinity)

                    titleBlock(track)

                    progressBlock

                    transportControls

                    Divider()

                    preferenceControls(for: track)

                    shuffleToggle
                } else {
                    ContentUnavailableView(
                        "Aucune lecture en cours",
                        systemImage: "music.note",
                        description: Text("Choisissez un morceau dans la bibliothèque.")
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .navigationTitle("Lecture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear { scrubPosition = player.currentTime }
        .onChange(of: player.currentTime) { _, newValue in
            // Pendant un déplacement du curseur par l'utilisateur, on ne
            // touche à rien : sinon le curseur « rebondit » sous le doigt.
            if !player.isScrubbing { scrubPosition = newValue }
        }
    }

    // MARK: - Morceaux d'interface

    @ViewBuilder
    private var artwork: some View {
        Group {
            if let image = player.artworkImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 54))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 220, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }

    private func titleBlock(_ track: Track) -> some View {
        VStack(spacing: 4) {
            Text(track.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(track.artistDisplayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var progressBlock: some View {
        VStack(spacing: 2) {
            Slider(
                value: $scrubPosition,
                in: 0...max(player.duration, 0.01)
            ) { editing in
                player.isScrubbing = editing
                if !editing { player.seek(to: scrubPosition) }
            }
            .disabled(player.duration <= 0)

            HStack {
                Text(TimeFormatter.string(from: scrubPosition))
                Spacer()
                Text("-" + TimeFormatter.string(from: max(0, player.duration - scrubPosition)))
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 36) {
            Button {
                player.playPrevious()
            } label: {
                Image(systemName: "backward.fill").font(.title)
            }
            .accessibilityLabel("Morceau précédent")

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Lecture")

            Button {
                player.playNext()
            } label: {
                Image(systemName: "forward.fill").font(.title)
            }
            .accessibilityLabel("Morceau suivant")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    private func preferenceControls(for track: Track) -> some View {
        let preferences = store.preferences(for: track.id)
        return VStack(spacing: 14) {
            ScoreControl(score: preferences.score, style: .expanded) { newScore in
                store.setScore(newScore, for: track.id)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preferences.isMuted ? "En sourdine" : "Dans la lecture aléatoire")
                        .font(.subheadline)
                    Text(preferences.isMuted
                         ? "Exclu du tirage aléatoire, toujours jouable à la main."
                         : "Peut être tiré au sort.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                MuteButton(isMuted: preferences.isMuted, large: true) {
                    store.toggleMuted(track.id)
                }
            }
        }
    }

    private var shuffleToggle: some View {
        Toggle(isOn: Binding(
            get: { player.isShuffleEnabled },
            set: { player.isShuffleEnabled = $0 }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lecture aléatoire intelligente")
                    .font(.subheadline)
                Text("Évite les répétitions et suit vos scores favoris.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
