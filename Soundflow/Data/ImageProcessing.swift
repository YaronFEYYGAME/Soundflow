import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Traitements d'image sans état, utilisables depuis n'importe quel fil.
///
/// Tout passe par ImageIO plutôt que par `UIImage(data:)`. La différence est
/// décisive pour la fiabilité : `UIImage(data:)` décode l'image **en entier**,
/// alors qu'ImageIO sait produire directement une version réduite sans jamais
/// matérialiser l'originale en mémoire. Une photo de 48 mégapixels décodée en
/// entier pèse près de 200 Mo — de quoi faire tuer l'app par iOS, lecture en
/// cours comprise.
enum ImageProcessing {

    /// Taille maximale (plus grand côté, en pixels) des images conservées.
    /// L'écran verrouillé d'un iPhone récent fait environ 1 200 × 2 600
    /// pixels : au-delà, on stockerait des détails que personne ne verra.
    static let maxStoredPixelSize = 2_600

    /// Taille des vignettes de la grille de choix.
    static let thumbnailPixelSize = 360

    /// Taille de l'image transmise à l'écran verrouillé.
    static let lockScreenPixelSize = 2_048

    /// Garde-fou contre un fichier démesuré (vidéo renommée, GIF de plusieurs
    /// minutes…). Mieux vaut refuser proprement que risquer la mémoire.
    static let maxImportBytes = 60 * 1_024 * 1_024

    enum ImportError: LocalizedError {
        case unreadable
        case tooLarge
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Ce fichier n'est pas une image lisible."
            case .tooLarge: return "Cette image est trop volumineuse (plus de 60 Mo)."
            case .encodingFailed: return "L'image n'a pas pu être enregistrée."
            }
        }
    }

    // MARK: - Préparation à l'import

    /// Prépare une image pour le stockage.
    ///
    /// - Un **GIF animé** est conservé tel quel : le réencoder détruirait
    ///   l'animation.
    /// - Toute autre image est réduite et réenregistrée en JPEG (ou en PNG si
    ///   elle comporte de la transparence). Au passage, l'orientation de
    ///   l'appareil photo est appliquée une fois pour toutes : une photo prise
    ///   téléphone tourné ne s'affichera jamais de travers.
    static func prepareForStorage(_ data: Data) throws -> (data: Data, fileExtension: String) {
        guard data.count <= maxImportBytes else { throw ImportError.tooLarge }
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0
        else { throw ImportError.unreadable }

        if isAnimatedGIF(source) {
            return (data, "gif")
        }

        guard let image = downsample(source, maxPixelSize: maxStoredPixelSize) else {
            throw ImportError.unreadable
        }

        let hasAlpha: Bool
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: hasAlpha = false
        default: hasAlpha = true
        }

        let type: UTType = hasAlpha ? .png : .jpeg
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            type.identifier as CFString,
            1,
            nil
        ) else { throw ImportError.encodingFailed }

        let properties = [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
        CGImageDestinationAddImage(destination, image, hasAlpha ? nil : properties)
        guard CGImageDestinationFinalize(destination) else { throw ImportError.encodingFailed }

        return (output as Data, hasAlpha ? "png" : "jpg")
    }

    // MARK: - Lecture

    /// `true` si le fichier est un GIF comportant plusieurs images.
    static func isAnimatedGIF(at url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        return isAnimatedGIF(source)
    }

    /// Version réduite d'une image sur disque (première image pour un GIF).
    static func downsampledImage(at url: URL, maxPixelSize: Int) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, options),
            let image = downsample(source, maxPixelSize: maxPixelSize)
        else { return nil }
        return UIImage(cgImage: image)
    }

    // MARK: - Interne

    private static func isAnimatedGIF(_ source: CGImageSource) -> Bool {
        guard CGImageSourceGetCount(source) > 1 else { return false }
        guard let identifier = CGImageSourceGetType(source) as String?,
              let type = UTType(identifier)
        else { return false }
        return type.conforms(to: .gif)
    }

    private static func downsample(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options = [
            // Toujours construire la version réduite depuis l'image complète,
            // plutôt que de réutiliser une éventuelle miniature intégrée au
            // fichier — souvent minuscule et floue.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            // Applique l'orientation EXIF (photo prise téléphone tourné).
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Décoder maintenant, sur ce fil de travail, plutôt qu'au premier
            // affichage, sur le fil de l'interface.
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
