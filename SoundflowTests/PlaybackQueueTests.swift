import XCTest
@testable import Soundflow

/// Tests de la file d'attente.
final class PlaybackQueueTests: XCTestCase {

    private func id(_ name: String) -> TrackID {
        TrackID(sourceID: "test", key: name)
    }

    private func keys(_ queue: PlaybackQueue) -> [String] {
        queue.entries.map(\.trackID.key)
    }

    private func makeQueue(_ names: [String]) -> PlaybackQueue {
        var queue = PlaybackQueue()
        for name in names { queue.enqueue(id(name)) }
        return queue
    }

    // MARK: - Ajout et lecture dans l'ordre

    func testEnqueueReturnsOneBasedPosition() {
        var queue = PlaybackQueue()
        XCTAssertEqual(queue.enqueue(id("a")), 1)
        XCTAssertEqual(queue.enqueue(id("b")), 2)
        XCTAssertEqual(queue.enqueue(id("c")), 3)
    }

    func testDequeuesInOrder() {
        var queue = makeQueue(["a", "b", "c"])
        let all = Set([id("a"), id("b"), id("c")])
        XCTAssertEqual(queue.dequeueNext(availableIn: all), id("a"))
        XCTAssertEqual(queue.dequeueNext(availableIn: all), id("b"))
        XCTAssertEqual(queue.dequeueNext(availableIn: all), id("c"))
        XCTAssertNil(queue.dequeueNext(availableIn: all))
        XCTAssertTrue(queue.isEmpty)
    }

    func testDequeueSkipsTracksDeletedMeanwhile() {
        var queue = makeQueue(["supprimé", "présent"])
        let next = queue.dequeueNext(availableIn: [id("présent")])
        XCTAssertEqual(next, id("présent"))
        XCTAssertTrue(queue.isEmpty, "Le morceau disparu doit aussi avoir quitté la file")
    }

    func testDequeueReturnsNilWhenNothingIsAvailable() {
        var queue = makeQueue(["a", "b"])
        XCTAssertNil(queue.dequeueNext(availableIn: []))
        XCTAssertTrue(queue.isEmpty)
    }

    // MARK: - Doublons

    func testSameTrackCanBeQueuedTwiceAndRemovedIndependently() {
        var queue = makeQueue(["a", "a"])
        XCTAssertEqual(queue.count, 2)
        XCTAssertNotEqual(queue.entries[0].id, queue.entries[1].id)

        let firstEntry = queue.entries[0].id
        XCTAssertEqual(queue.remove(id: firstEntry), id("a"))
        XCTAssertEqual(queue.count, 1, "Un seul exemplaire doit avoir été retiré")
    }

    func testRemoveUnknownEntryReturnsNil() {
        var queue = makeQueue(["a"])
        XCTAssertNil(queue.remove(id: UUID()))
        XCTAssertEqual(queue.count, 1)
    }

    // MARK: - Suppression par positions

    func testRemoveAtOffsets() {
        var queue = makeQueue(["a", "b", "c", "d"])
        queue.remove(atOffsets: [1, 3])
        XCTAssertEqual(keys(queue), ["a", "c"])
    }

    func testRemoveAtOffsetsIgnoresOutOfRangeIndices() {
        var queue = makeQueue(["a", "b"])
        queue.remove(atOffsets: [5])
        XCTAssertEqual(keys(queue), ["a", "b"])
    }

    // MARK: - Déplacement (même sémantique que SwiftUI)

    func testMoveMatchesAppleDocumentedExample() {
        // Exemple tiré de la documentation d'Apple pour
        // `move(fromOffsets:toOffset:)` : c'est la référence à respecter,
        // puisque ce sont ces valeurs que la liste SwiftUI nous transmet.
        var queue = makeQueue(["a", "b", "c", "d", "e"])
        queue.move(fromOffsets: [1, 3], toOffset: 5)
        XCTAssertEqual(keys(queue), ["a", "c", "e", "b", "d"])
    }

    func testMoveFirstToLaterPosition() {
        var queue = makeQueue(["a", "b", "c", "d"])
        queue.move(fromOffsets: [0], toOffset: 3)
        XCTAssertEqual(keys(queue), ["b", "c", "a", "d"])
    }

    func testMoveLastToFront() {
        var queue = makeQueue(["a", "b", "c", "d"])
        queue.move(fromOffsets: [3], toOffset: 0)
        XCTAssertEqual(keys(queue), ["d", "a", "b", "c"])
    }

    func testMoveOntoItselfChangesNothing() {
        var queue = makeQueue(["a", "b", "c"])
        queue.move(fromOffsets: [0], toOffset: 0)
        XCTAssertEqual(keys(queue), ["a", "b", "c"])
        queue.move(fromOffsets: [0], toOffset: 1)
        XCTAssertEqual(keys(queue), ["a", "b", "c"])
    }

    func testMoveWithOutOfRangeDestinationIsClamped() {
        var queue = makeQueue(["a", "b", "c"])
        queue.move(fromOffsets: [0], toOffset: 99)
        XCTAssertEqual(keys(queue), ["b", "c", "a"])
    }

    func testRemoveAll() {
        var queue = makeQueue(["a", "b"])
        queue.removeAll()
        XCTAssertTrue(queue.isEmpty)
    }
}
