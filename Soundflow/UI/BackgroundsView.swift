import SwiftUI

/// Onglet « Fonds » : choisir l'image qui remplace la pochette des morceaux.
///
/// Un tap choisit. La tuile « Aucun » rend leur pochette aux morceaux. Un
/// appui long sur un fond propose de le supprimer.
struct BackgroundsView: View {
    @Environment(BackgroundStore.self) private var store

    let onAddFromPhotos: () -> Void
    let onAddFromFiles: () -> Void

    /// Tuiles au format portrait, comme un écran verrouillé : l'utilisateur
    /// voit ce que donnera vraiment son image.
    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                noneTile

                ForEach(store.backgrounds) { background in
                    BackgroundTile(
                        thumbnail: store.thumbnails[background.id],
                        isAnimated: background.isAnimated,
                        isSelected: store.selectedID == background.id
                    )
                    .onTapGesture { store.select(background.id) }
                    .contextMenu {
                        Button(role: .destructive) {
                            store.delete(background)
                        } label: {
                            Label("Supprimer ce fond", systemImage: "trash")
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(background.isAnimated ? "Fond animé" : "Fond")
                    .accessibilityAddTraits(store.selectedID == background.id ? [.isSelected] : [])
                }

                addTile
            }
            .padding(16)

            VStack(alignment: .leading, spacing: 6) {
                Text("Le fond choisi remplace la pochette de tous les morceaux : dans l'app, sur l'écran verrouillé et dans le centre de contrôle.")
                Text("Les GIF s'animent dans l'app. L'écran verrouillé, lui, n'affiche que leur première image : c'est une limite d'iOS pour les apps autres que Musique.")
                Text("Appui long sur un fond pour le supprimer.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var noneTile: some View {
        TileFrame(isSelected: store.selectedID == nil) {
            VStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.title2)
                Text("Aucun")
                    .font(.footnote.weight(.medium))
                Text("pochettes des morceaux")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.1))
        }
        .onTapGesture { store.select(nil) }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Aucun fond, utiliser les pochettes des morceaux")
        .accessibilityAddTraits(store.selectedID == nil ? [.isSelected] : [])
    }

    private var addTile: some View {
        Menu {
            Button(action: onAddFromPhotos) {
                Label("Depuis Photos", systemImage: "photo.on.rectangle")
            }
            Button(action: onAddFromFiles) {
                Label("Depuis Fichiers", systemImage: "folder")
            }
        } label: {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Color.accentColor)
                .aspectRatio(9 / 16, contentMode: .fit)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text("Ajouter")
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(Color.accentColor)
                }
        }
        .accessibilityLabel("Ajouter un fond")
    }
}

private struct BackgroundTile: View {
    let thumbnail: UIImage?
    let isAnimated: Bool
    let isSelected: Bool

    var body: some View {
        TileFrame(isSelected: isSelected) {
            ZStack(alignment: .bottomLeading) {
                if let thumbnail {
                    // `Color.clear` + overlay : l'image remplit la tuile sans
                    // jamais en dicter la taille, quel que soit son format.
                    Color.clear
                        .overlay {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                } else {
                    Color.secondary.opacity(0.15)
                        .overlay { ProgressView() }
                }

                if isAnimated {
                    Text("GIF")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
            }
        }
    }
}

/// Cadre commun des tuiles : format portrait, coins arrondis, et marque de
/// sélection bien visible.
private struct TileFrame<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .aspectRatio(9 / 16, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                                  lineWidth: isSelected ? 3 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
