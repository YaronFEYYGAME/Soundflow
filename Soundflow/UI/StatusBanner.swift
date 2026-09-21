import SwiftUI

/// Bandeau d'information temporaire.
///
/// Volontairement préféré à une alerte modale : un message du type
/// « 3 morceaux ajoutés » ne mérite pas d'interrompre l'utilisateur ni,
/// surtout, d'interrompre la lecture en cours.
struct StatusBanner: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(isError ? Color.orange : Color.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.isStaticText)
    }
}
