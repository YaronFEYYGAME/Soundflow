import SwiftUI

/// Réglage du score favori (-2 … +2).
///
/// Contrainte de conception imposée : ce réglage doit s'atteindre en un ou
/// deux gestes, et ne jamais être caché derrière un menu. D'où deux formes :
///
/// - `compact` : deux boutons « − » et « + » encadrant la valeur, affichés en
///   permanence sur chaque ligne de la liste. Un tap = un cran.
/// - `expanded` : un sélecteur segmenté à cinq positions sur l'écran de
///   lecture. Un tap = la valeur voulue, directement.
struct ScoreControl: View {

    enum Style {
        case compact
        case expanded
    }

    let score: Int
    var style: Style = .compact
    let onSet: (Int) -> Void

    var body: some View {
        switch style {
        case .compact: compactBody
        case .expanded: expandedBody
        }
    }

    // MARK: - Compact

    private var compactBody: some View {
        HStack(spacing: 2) {
            stepButton(
                systemName: "minus",
                enabled: score > TrackPreferences.scoreRange.lowerBound,
                label: "Diminuer la fréquence"
            ) {
                onSet(score - 1)
            }

            Text(Self.scoreText(score))
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Self.color(for: score))
                .frame(minWidth: 24)

            stepButton(
                systemName: "plus",
                enabled: score < TrackPreferences.scoreRange.upperBound,
                label: "Augmenter la fréquence"
            ) {
                onSet(score + 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Score favori")
        .accessibilityValue(TrackPreferences(score: score).scoreLabel)
    }

    private func stepButton(
        systemName: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 28, height: 32)
                .contentShape(Rectangle())
        }
        // `.borderless` est indispensable dans une `List` : sans lui, iOS
        // considère toute la ligne comme un seul bouton et les deux contrôles
        // deviennent inutilisables.
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .foregroundStyle(enabled ? Color.accentColor : Color.secondary.opacity(0.4))
        .accessibilityLabel(label)
    }

    // MARK: - Étendu

    private var expandedBody: some View {
        VStack(spacing: 6) {
            Picker("Score favori", selection: Binding(
                get: { score },
                set: { onSet($0) }
            )) {
                ForEach(Array(TrackPreferences.scoreRange), id: \.self) { value in
                    Text(Self.scoreText(value)).tag(value)
                }
            }
            .pickerStyle(.segmented)

            Text(TrackPreferences(score: score).scoreLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Présentation

    static func scoreText(_ score: Int) -> String {
        switch score {
        case let value where value > 0: return "+\(value)"
        case let value where value < 0: return "−\(abs(value))"
        default: return "0"
        }
    }

    static func color(for score: Int) -> Color {
        switch score {
        case let value where value > 0: return .accentColor
        case let value where value < 0: return .secondary
        default: return .secondary
        }
    }
}

/// Bouton de mise en sourdine, toujours visible lui aussi.
struct MuteButton: View {
    let isMuted: Bool
    var large: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                .font(.system(size: large ? 18 : 14, weight: .medium))
                .frame(width: large ? 44 : 32, height: large ? 44 : 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isMuted ? Color.orange : Color.secondary)
        .accessibilityLabel(isMuted ? "Réactiver dans la lecture aléatoire" : "Mettre en sourdine")
        .accessibilityAddTraits(isMuted ? [.isSelected] : [])
    }
}
