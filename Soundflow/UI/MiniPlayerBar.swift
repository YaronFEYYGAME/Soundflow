import SwiftUI

/// Barre de lecture permanente, ancrée en bas de la bibliothèque.
///
/// Elle sert deux besoins : savoir en permanence ce qui joue, et mettre en
/// pause ou passer au suivant sans changer d'écran. Un tap dessus ouvre
/// l'écran de lecture complet.
struct MiniPlayerBar: View {
    @Environment(PlayerController.self) private var player

    let onOpen: () -> Void

    var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                progressLine

                HStack(spacing: 12) {
                    artwork

                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(track.artistDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onOpen)

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Lecture")

                    Button {
                        player.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Morceau suivant")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(.regularMaterial)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * player.progress)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = player.artworkImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
