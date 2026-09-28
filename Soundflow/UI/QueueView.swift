import SwiftUI

/// La file d'attente, ouverte depuis l'écran de lecture.
///
/// - tap sur un morceau : il passe tout de suite (et quitte la file) ;
/// - balayage vers la gauche : il est retiré ;
/// - « Modifier » : poignées pour réordonner par glisser-déposer.
struct QueueView: View {
    @Environment(PlayerController.self) private var player
    @Environment(LibraryModel.self) private var library
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let current = player.currentTrack {
                    Section("En cours") {
                        QueueTrackRow(track: current, isCurrent: true)
                    }
                }

                Section {
                    if player.queue.isEmpty {
                        Text("La file est vide.\nDans la bibliothèque, balayez un morceau vers la droite pour l'ajouter ici.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(player.queue.entries) { entry in
                            if let track = library.track(with: entry.trackID) {
                                Button {
                                    player.playFromQueue(entry.id)
                                } label: {
                                    QueueTrackRow(track: track, isCurrent: false)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("Morceau supprimé — il sera ignoré.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { player.removeFromQueue(atOffsets: $0) }
                        .onMove { player.moveQueue(fromOffsets: $0, toOffset: $1) }
                    }
                } header: {
                    Text(player.queue.isEmpty ? "À suivre" : "À suivre (\(player.queue.count))")
                } footer: {
                    Text(player.isShuffleEnabled
                         ? "Une fois la file terminée, la lecture aléatoire reprend."
                         : "Une fois la file terminée, la lecture continue dans l'ordre de la liste.")
                }
            }
            .navigationTitle("File d'attente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !player.queue.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    if !player.queue.isEmpty {
                        Button("Vider la file", role: .destructive) {
                            player.clearQueue()
                        }
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

private struct QueueTrackRow: View {
    let track: Track
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .lineLimit(1)
                Text(track.artistDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let duration = track.duration {
                Text(TimeFormatter.string(from: duration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
