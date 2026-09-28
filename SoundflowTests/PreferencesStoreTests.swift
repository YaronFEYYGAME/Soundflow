import XCTest
@testable import Soundflow

/// Tests du stockage des réglages.
///
/// Ce qui est vérifié ici n'est pas « est-ce que ça marche une fois », mais
/// « est-ce que les réglages de l'utilisateur survivent ». C'est exactement
/// le genre de perte silencieuse qui détruit la confiance dans une app.
@MainActor
final class PreferencesStoreTests: XCTestCase {

    private var temporaryDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "SoundflowTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        fileURL = temporaryDirectory.appending(path: "state.json")
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try super.tearDownWithError()
    }

    private func id(_ name: String) -> TrackID {
        TrackID(sourceID: "local", key: name)
    }

    // MARK: - Bornes du score

    func testScoreIsClampedToRange() {
        let store = PreferencesStore(fileURL: fileURL)
        let track = id("a.mp3")

        store.setScore(10, for: track)
        XCTAssertEqual(store.score(for: track), 2)

        store.setScore(-10, for: track)
        XCTAssertEqual(store.score(for: track), -2)
    }

    func testAdjustScoreStopsAtBounds() {
        let store = PreferencesStore(fileURL: fileURL)
        let track = id("a.mp3")

        for _ in 0..<10 { store.adjustScore(by: 1, for: track) }
        XCTAssertEqual(store.score(for: track), 2)

        for _ in 0..<10 { store.adjustScore(by: -1, for: track) }
        XCTAssertEqual(store.score(for: track), -2)
    }

    func testDefaultPreferencesAreNeutral() {
        let store = PreferencesStore(fileURL: fileURL)
        let preferences = store.preferences(for: id("jamais-vu.mp3"))
        XCTAssertEqual(preferences.score, 0)
        XCTAssertFalse(preferences.isMuted)
    }

    // MARK: - Sourdine

    func testToggleMute() {
        let store = PreferencesStore(fileURL: fileURL)
        let track = id("a.mp3")

        XCTAssertFalse(store.isMuted(track))
        store.toggleMuted(track)
        XCTAssertTrue(store.isMuted(track))
        store.toggleMuted(track)
        XCTAssertFalse(store.isMuted(track))
    }

    // MARK: - Persistance

    func testPreferencesSurviveRelaunch() async throws {
        let first = PreferencesStore(fileURL: fileURL)
        first.setScore(2, for: id("aimé.mp3"))
        first.setScore(-1, for: id("moyen.mp3"))
        first.setMuted(true, for: id("silence.mp3"))
        first.recordPlay(of: id("aimé.mp3"))
        await first.flush()

        let second = PreferencesStore(fileURL: fileURL)
        XCTAssertEqual(second.score(for: id("aimé.mp3")), 2)
        XCTAssertEqual(second.score(for: id("moyen.mp3")), -1)
        XCTAssertTrue(second.isMuted(id("silence.mp3")))
        XCTAssertEqual(second.history.first, id("aimé.mp3"))
    }

    func testCorruptedFileDoesNotPreventStartup() throws {
        try Data("ceci n'est pas du JSON".utf8).write(to: fileURL)
        let store = PreferencesStore(fileURL: fileURL)
        XCTAssertTrue(store.preferences.isEmpty)
        XCTAssertTrue(store.history.isEmpty)
        // Et l'app reste utilisable : on peut de nouveau enregistrer.
        store.setScore(1, for: id("a.mp3"))
        XCTAssertEqual(store.score(for: id("a.mp3")), 1)
    }

    func testNeutralPreferencesAreNotStored() async throws {
        let store = PreferencesStore(fileURL: fileURL)
        store.setScore(2, for: id("a.mp3"))
        store.setScore(0, for: id("a.mp3"))
        await store.flush()

        let data = try Data(contentsOf: fileURL)
        let state = try JSONDecoder().decode(LibraryStateFile.self, from: data)
        XCTAssertTrue(state.entries.isEmpty, "Une préférence neutre ne doit pas occuper le fichier")
    }

    // MARK: - Historique

    func testHistoryKeepsMostRecentFirstWithoutDuplicates() {
        let store = PreferencesStore(fileURL: fileURL)
        store.recordPlay(of: id("a.mp3"))
        store.recordPlay(of: id("b.mp3"))
        store.recordPlay(of: id("a.mp3"))

        XCTAssertEqual(store.history, [id("a.mp3"), id("b.mp3")])
    }

    func testHistoryIsCapped() {
        let store = PreferencesStore(fileURL: fileURL)
        for index in 0..<(PreferencesStore.historyLimit + 50) {
            store.recordPlay(of: id("track-\(index).mp3"))
        }
        XCTAssertEqual(store.history.count, PreferencesStore.historyLimit)
        XCTAssertEqual(store.history.first, id("track-\(PreferencesStore.historyLimit + 49).mp3"))
    }

    // MARK: - Oubli explicite

    func testForgetRemovesOnlyThatTrack() {
        let store = PreferencesStore(fileURL: fileURL)
        store.setScore(2, for: id("reste.mp3"))
        store.setScore(1, for: id("supprimé.mp3"))
        store.recordPlay(of: id("supprimé.mp3"))
        store.recordPlay(of: id("reste.mp3"))

        store.forget(id("supprimé.mp3"))

        XCTAssertEqual(store.score(for: id("reste.mp3")), 2)
        XCTAssertEqual(store.score(for: id("supprimé.mp3")), 0)
        XCTAssertEqual(store.history, [id("reste.mp3")])
    }

    // MARK: - Migration depuis l'ancien emplacement

    func testMigratesLegacyFileOnFirstLaunch() async throws {
        let legacyURL = temporaryDirectory.appending(path: "ancien/library-state.json")
        let old = PreferencesStore(fileURL: legacyURL)
        old.setScore(2, for: id("aimé.mp3"))
        old.setMuted(true, for: id("silence.mp3"))
        await old.flush()

        let store = PreferencesStore(fileURL: fileURL, legacyFileURL: legacyURL)

        XCTAssertEqual(store.score(for: id("aimé.mp3")), 2)
        XCTAssertTrue(store.isMuted(id("silence.mp3")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: legacyURL.path(percentEncoded: false)),
            "L'ancien fichier doit disparaître une fois repris"
        )
    }

    func testMigrationNeverOverwritesExistingNewFile() async throws {
        let current = PreferencesStore(fileURL: fileURL)
        current.setScore(1, for: id("a.mp3"))
        await current.flush()

        let legacyURL = temporaryDirectory.appending(path: "ancien/library-state.json")
        let old = PreferencesStore(fileURL: legacyURL)
        old.setScore(-2, for: id("a.mp3"))
        await old.flush()

        let store = PreferencesStore(fileURL: fileURL, legacyFileURL: legacyURL)
        XCTAssertEqual(store.score(for: id("a.mp3")), 1, "Le nouveau fichier fait foi")
    }

    // MARK: - Rechargement après remplacement externe

    func testReloadsWhenFileIsReplacedFromOutside() async throws {
        let store = PreferencesStore(fileURL: fileURL)
        store.setScore(1, for: id("a.mp3"))
        await store.flush()

        // Réglages d'une autre installation, copiés via l'app Fichiers.
        let otherURL = temporaryDirectory.appending(path: "autre/Soundflow-reglages.json")
        let other = PreferencesStore(fileURL: otherURL)
        other.setScore(-2, for: id("a.mp3"))
        other.setMuted(true, for: id("b.mp3"))
        await other.flush()

        try FileManager.default.removeItem(at: fileURL)
        try FileManager.default.copyItem(at: otherURL, to: fileURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(120)],
            ofItemAtPath: fileURL.path(percentEncoded: false)
        )

        XCTAssertTrue(store.reloadIfChangedOnDisk())
        XCTAssertEqual(store.score(for: id("a.mp3")), -2)
        XCTAssertTrue(store.isMuted(id("b.mp3")))
        XCTAssertFalse(store.reloadIfChangedOnDisk(), "Rien n'a changé depuis : pas de rechargement")
    }

    func testDoesNotReloadAfterItsOwnWrites() async {
        let store = PreferencesStore(fileURL: fileURL)
        store.setScore(2, for: id("a.mp3"))
        await store.flush()
        XCTAssertFalse(store.reloadIfChangedOnDisk())
        XCTAssertEqual(store.score(for: id("a.mp3")), 2)
    }
}

/// Tests de l'identifiant de morceau : c'est la clé de voûte de la
/// séparation entre sources, il vaut mieux qu'elle soit solide.
final class TrackIDTests: XCTestCase {

    func testSplitsSourceAndKey() {
        let identifier = TrackID(sourceID: "local", key: "Ma chanson.mp3")
        XCTAssertEqual(identifier.rawValue, "local:Ma chanson.mp3")
        XCTAssertEqual(identifier.sourceID, "local")
        XCTAssertEqual(identifier.key, "Ma chanson.mp3")
    }

    func testKeyMayContainColons() {
        let identifier = TrackID(sourceID: "dropbox", key: "dossier:sous-dossier/titre.mp3")
        XCTAssertEqual(identifier.sourceID, "dropbox")
        XCTAssertEqual(identifier.key, "dossier:sous-dossier/titre.mp3")
    }

    func testCodableRoundTripUsesAPlainString() throws {
        let identifier = TrackID(sourceID: "local", key: "a.mp3")
        let data = try JSONEncoder().encode(identifier)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"local:a.mp3\"")
        XCTAssertEqual(try JSONDecoder().decode(TrackID.self, from: data), identifier)
    }
}
