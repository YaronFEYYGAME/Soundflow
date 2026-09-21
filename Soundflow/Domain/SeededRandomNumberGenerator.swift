import Foundation

/// Générateur pseudo-aléatoire déterministe (algorithme SplitMix64).
///
/// Il n'est pas utilisé par l'application elle-même : il sert exclusivement
/// aux tests. Avec une même graine, il produit toujours la même suite de
/// nombres, ce qui permet de tester un algorithme aléatoire de façon fiable
/// et reproductible — un test qui échoue une fois sur cent est pire que pas
/// de test du tout.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
