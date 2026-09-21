import SwiftUI

/// Une ligne de la bibliothèque.
///
/// Trois zones, toutes atteignables sans menu :
/// 1. le texte — un tap lance le morceau ;
/// 2. le score favori — un tap par cran ;
/// 3. la sourdine — un tap.
struct TrackRow: View {
    let track: Track
    let preferences: TrackPreferences
    let isCurrent: Bool
    let isPlaying: Bool

    let onPlay: () -> Void
    let onSetScore: (Int) -> Void
    let onToggleMute: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            indicator

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(preferences.isMuted ? Color.secondary : Color.primary)

                HStack(spacing: 4) {
                    Text(track.artistDisplayName)
                        .lineLimit(1)
                    if let duration = track.duration {
                        Text("·")
                        Text(TimeFormatter.string(from: duration))
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            // Le texte prend toute la place restante et c'est lui qui porte
            // le geste « jouer ».
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onPlay)

            ScoreControl(score: preferences.score, style: .compact, onSet: onSetScore)

            MuteButton(isMuted: preferences.isMuted, action: onToggleMute)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }

    /// Petit repère de lecture en cours. Discret : pas d'animation coûteuse,
    /// juste une icône — l'écran reste calme.
    @ViewBuilder
    private var indicator: some View {
        Group {
            if isCurrent {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            } else {
                Color.clear
            }
        }
        .frame(width: 14)
        .accessibilityHidden(true)
    }
}
