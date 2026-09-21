import XCTest
@testable import Soundflow

/// Tests de l'algorithme de lecture aléatoire.
///
/// Un algorithme aléatoire est le genre de code où un bug ne se voit pas :
/// « il m'a semblé qu'il répétait » n'est pas un rapport de bug exploitable.
/// D'où ces tests, qui rejouent des dizaines de milliers de tirages avec un
/// générateur déterministe et vérifient les promesses faites à l'utilisateur.
final class SmartShuffleTests: XCTestCase {

    // MARK: - Utilitaires

    private func makeIDs(_ count: Int) -> [TrackID] {
        (0..<count).map { TrackID(sourceID: "test", key: "track-\($0).mp3") }
    }

    /// Simule une session d'écoute et renvoie l'ordre des morceaux joués.
    private func simulate(
        library: [TrackID],
        preferences: [TrackID: TrackPreferences] = [:],
        plays: Int,
        seed: UInt64 = 42,
        configuration: ShuffleConfiguration = .default
    ) -> [TrackID] {
        let shuffle = SmartShuffle(configuration: configuration)
        var generator = SeededRandomNumberGenerator(seed: seed)
        var history: [TrackID] = []
        var played: [TrackID] = []

        for _ in 0..<plays {
            guard let next = shuffle.pickNext(
                from: library,
                preferences: preferences,
                history: history,
                using: &generator
            ) else { break }
            played.append(next)
            history.insert(next, at: 0)
            if history.count > PreferencesStore.historyLimit {
                history.removeLast()
            }
        }
        return played
    }

    // MARK: - Poids liés au score

    func testWeightMapping() {
        XCTAssertEqual(SmartShuffle.weight(forScore: 0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(SmartShuffle.weight(forScore: 1), 2.0, accuracy: 0.0001)
        XCTAssertEqual(SmartShuffle.weight(forScore: 2), 3.0, accuracy: 0.0001)
        XCTAssertEqual(SmartShuffle.weight(forScore: -1), 0.5, accuracy: 0.0001)
        XCTAssertEqual(SmartShuffle.weight(forScore: -2), 1.0 / 3.0, accuracy: 0.0001)
    }

    func testWeightIsClampedForOutOfRangeScores() {
        XCTAssertEqual(SmartShuffle.weight(forScore: 99), SmartShuffle.weight(forScore: 2))
        XCTAssertEqual(SmartShuffle.weight(forScore: -99), SmartShuffle.weight(forScore: -2))
    }

    // MARK: - Promesse n°1 : jamais deux fois de suite

    func testNeverRepeatsImmediately() {
        for librarySize in [2, 3, 5, 12, 50] {
            for seed in [1, 7, 99, 12_345] as [UInt64] {
                let played = simulate(library: makeIDs(librarySize), plays: 800, seed: seed)
                XCTAssertEqual(played.count, 800)
                for index in 1..<played.count {
                    XCTAssertNotEqual(
                        played[index],
                        played[index - 1],
                        "Répétition immédiate avec \(librarySize) morceaux (graine \(seed))"
                    )
                }
            }
        }
    }

    func testNeverRepeatsImmediatelyEvenWhenMostTracksAreMuted() {
        let library = makeIDs(10)
        var preferences: [TrackID: TrackPreferences] = [:]
        // Il ne reste que deux morceaux jouables : le cas le plus dur.
        for id in library.dropFirst(2) {
            preferences[id] = TrackPreferences(score: 0, isMuted: true)
        }
        let played = simulate(library: library, preferences: preferences, plays: 500)
        XCTAssertEqual(Set(played), Set(library.prefix(2)))
        for index in 1..<played.count {
            XCTAssertNotEqual(played[index], played[index - 1])
        }
    }

    // MARK: - Promesse n°2 : pas de répétition rapprochée

    func testRespectsCooldownWindow() {
        let librarySize = 20
        let library = makeIDs(librarySize)
        let shuffle = SmartShuffle()
        let cooldown = shuffle.hardCooldownSize(eligibleCount: librarySize)
        XCTAssertGreaterThan(cooldown, 1)

        let played = simulate(library: library, plays: 2_000)
        var lastIndex: [TrackID: Int] = [:]
        for (index, id) in played.enumerated() {
            if let previous = lastIndex[id] {
                XCTAssertGreaterThan(
                    index - previous,
                    cooldown,
                    "Le morceau \(id) est revenu trop vite (écart \(index - previous), minimum \(cooldown + 1))"
                )
            }
            lastIndex[id] = index
        }
    }

    func testCooldownSizeStaysWithinBounds() {
        let shuffle = SmartShuffle()
        XCTAssertEqual(shuffle.hardCooldownSize(eligibleCount: 1), 0)
        XCTAssertEqual(shuffle.hardCooldownSize(eligibleCount: 2), 1)
        // Jamais plus de `eligibleCount - 1`, sinon plus rien n'est jouable.
        for count in 2...200 {
            let cooldown = shuffle.hardCooldownSize(eligibleCount: count)
            XCTAssertGreaterThanOrEqual(cooldown, 1)
            XCTAssertLessThanOrEqual(cooldown, count - 1)
            XCTAssertLessThanOrEqual(cooldown, ShuffleConfiguration.default.maximumHardCooldown)
        }
    }

    // MARK: - Sourdine

    func testMutedTracksAreNeverPicked() {
        let library = makeIDs(8)
        var preferences: [TrackID: TrackPreferences] = [:]
        preferences[library[0]] = TrackPreferences(score: 2, isMuted: true)
        preferences[library[3]] = TrackPreferences(score: 0, isMuted: true)

        let played = simulate(library: library, preferences: preferences, plays: 3_000)
        XCTAssertFalse(played.contains(library[0]), "Un morceau en sourdine a été tiré")
        XCTAssertFalse(played.contains(library[3]), "Un morceau en sourdine a été tiré")
    }

    func testReturnsNilWhenEverythingIsMuted() {
        let library = makeIDs(5)
        let preferences = Dictionary(
            uniqueKeysWithValues: library.map { ($0, TrackPreferences(score: 0, isMuted: true)) }
        )
        var generator = SeededRandomNumberGenerator(seed: 3)
        let picked = SmartShuffle().pickNext(
            from: library,
            preferences: preferences,
            history: [],
            using: &generator
        )
        XCTAssertNil(picked)
    }

    func testSingleTrackLibraryAlwaysReturnsThatTrack() {
        let library = makeIDs(1)
        let played = simulate(library: library, plays: 10)
        XCTAssertEqual(played, Array(repeating: library[0], count: 10))
    }

    func testEmptyLibraryReturnsNil() {
        var generator = SeededRandomNumberGenerator(seed: 1)
        let picked = SmartShuffle().pickNext(
            from: [],
            preferences: [:],
            history: [],
            using: &generator
        )
        XCTAssertNil(picked)
    }

    // MARK: - Influence du score sur la fréquence

    func testPositiveScoresArePlayedMoreOften() {
        let library = makeIDs(30)
        var preferences: [TrackID: TrackPreferences] = [:]
        preferences[library[0]] = TrackPreferences(score: 2)
        preferences[library[1]] = TrackPreferences(score: -2)

        let played = simulate(library: library, plays: 30_000)
        var counts: [TrackID: Int] = [:]
        for id in played { counts[id, default: 0] += 1 }

        let favourite = counts[library[0]] ?? 0
        let disliked = counts[library[1]] ?? 0
        let neutral = counts[library[5]] ?? 0

        XCTAssertGreaterThan(favourite, neutral, "Un score +2 doit sortir plus souvent qu'un neutre")
        XCTAssertLessThan(disliked, neutral, "Un score -2 doit sortir moins souvent qu'un neutre")
        // L'écart exact est adouci par la fenêtre anti-répétition ; on vérifie
        // l'ordre de grandeur, pas une valeur au centième près.
        XCTAssertGreaterThan(Double(favourite) / Double(max(disliked, 1)), 2.0)
    }

    func testScoreOrderingIsMonotonic() {
        let library = makeIDs(40)
        var preferences: [TrackID: TrackPreferences] = [:]
        for (offset, score) in zip(0..<5, [-2, -1, 0, 1, 2]) {
            preferences[library[offset]] = TrackPreferences(score: score)
        }

        let played = simulate(library: library, plays: 40_000, seed: 2_024)
        var counts: [TrackID: Int] = [:]
        for id in played { counts[id, default: 0] += 1 }

        let tallies = (0..<5).map { counts[library[$0]] ?? 0 }
        for index in 1..<tallies.count {
            XCTAssertGreaterThan(
                tallies[index],
                tallies[index - 1],
                "Les fréquences doivent croître avec le score : \(tallies)"
            )
        }
    }

    // MARK: - Déterminisme des tests eux-mêmes

    func testSameSeedProducesSameSequence() {
        let library = makeIDs(15)
        let first = simulate(library: library, plays: 200, seed: 777)
        let second = simulate(library: library, plays: 200, seed: 777)
        XCTAssertEqual(first, second)
    }

    func testDifferentSeedsProduceDifferentSequences() {
        let library = makeIDs(15)
        let first = simulate(library: library, plays: 200, seed: 1)
        let second = simulate(library: library, plays: 200, seed: 2)
        XCTAssertNotEqual(first, second)
    }
}
