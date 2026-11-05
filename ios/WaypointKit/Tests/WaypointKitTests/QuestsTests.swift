import Foundation
import XCTest
@testable import WaypointKit

final class QuestsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    func testCompletionIsExplicitAndDuplicateActionsDoNotDuplicateXP() throws {
        var book = QuestBook(); let quest = Quest(title: "Example task")
        try book.save(quest)
        XCTAssertEqual(book.xp, 0); XCTAssertNil(book.quests[0].completedAt)
        XCTAssertTrue(book.complete(quest.id)); XCTAssertFalse(book.complete(quest.id))
        XCTAssertEqual(book.xp, 20); XCTAssertEqual(book.rewards.count, 1)
        book.reopen(quest.id); XCTAssertEqual(book.xp, 0); XCTAssertNil(book.quests[0].completedAt)
        XCTAssertTrue(book.complete(quest.id)); XCTAssertEqual(book.xp, 20)
    }
    func testDeletedCompletedQuestKeepsAnonymousRewardAndRestores() throws {
        var book = QuestBook(); let quest = Quest(title: "Example task", notes: "Private note")
        try book.save(quest); book.complete(quest.id); book.delete(quest.id)
        let data = try JSONEncoder().encode(book)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Private note"))
        let restored = try QuestBook.restore(data)
        XCTAssertTrue(restored.quests.isEmpty); XCTAssertEqual(restored.xp, 20)
    }
    func testTitlesNotesCoordinatesAndDurationsAreValidated() throws {
        XCTAssertNil(QuestBook.title(" ")); XCTAssertNil(QuestBook.title("bad\nname"))
        XCTAssertNil(QuestBook.title(String(repeating: "a", count: 161)))
        XCTAssertEqual(QuestBook.title(" Example "), "Example")
        var book = QuestBook()
        XCTAssertThrowsError(try book.save(Quest(title: "Example", focusMinutes: 0)))
        XCTAssertThrowsError(try book.save(Quest(title: "Example", notes: String(repeating: "a", count: 2001))))
        XCTAssertThrowsError(try book.save(Quest(title: "Example", place: Place(id: "invalid", name: "Invalid", address: "", coordinate: Coordinate(latitude: 91, longitude: 0)))))
    }
    func testTimerUsesMonotonicTimeAndNeverCompletesTaskAutomatically() throws {
        var book = QuestBook(); let quest = Quest(title: "Focus", focusMinutes: 10)
        try book.save(quest)
        XCTAssertTrue(book.startFocus(quest.id, uptime: 100, now: now, bootID: "boot"))
        XCTAssertEqual(book.focus?.secondsLeft(uptime: 110, now: now.addingTimeInterval(99_999), bootID: "boot"), 590)
        book.finishFocus(confirm: true, uptime: 700, now: now, bootID: "boot")
        XCTAssertTrue(book.quests[0].focusFinished); XCTAssertNil(book.quests[0].completedAt); XCTAssertEqual(book.xp, 0)
        book.complete(quest.id); XCTAssertEqual(book.xp, 30)
        book.reopen(quest.id); XCTAssertEqual(book.xp, 0); XCTAssertEqual(book.focusedCount, 0)
    }
    func testEarlyFinishAndShortSessionsDoNotEarnFocusBonus() throws {
        var book = QuestBook(); let quest = Quest(title: "Early", focusMinutes: 25)
        try book.save(quest); _ = book.startFocus(quest.id, uptime: 0, now: now, bootID: "boot")
        book.finishFocus(confirm: false, uptime: 20, now: now, bootID: "boot")
        XCTAssertNil(book.focus); XCTAssertFalse(book.quests[0].focusFinished)
        book.complete(quest.id); XCTAssertEqual(book.xp, 20)
        let short = Quest(title: "Short", focusMinutes: 1)
        try book.save(short); _ = book.startFocus(short.id, uptime: 0, now: now, bootID: "boot")
        book.finishFocus(confirm: true, uptime: 60, now: now, bootID: "boot")
        book.complete(short.id); XCTAssertEqual(book.xp, 40)
    }
    func testOnlyOneFocusAndPauseResumePreserveRemainingTime() throws {
        var book = QuestBook(); let first = Quest(title: "First"), second = Quest(title: "Second")
        try book.save(first); try book.save(second)
        XCTAssertTrue(book.startFocus(first.id, uptime: 100, now: now, bootID: "boot"))
        XCTAssertFalse(book.startFocus(second.id, uptime: 100, now: now, bootID: "boot"))
        book.focus?.pause(uptime: 110, now: now, bootID: "boot")
        XCTAssertEqual(book.focus?.secondsLeft(uptime: 999, now: now, bootID: "boot"), 1490)
        book.focus?.resume(uptime: 1000, now: now, bootID: "boot")
        XCTAssertEqual(book.focus?.secondsLeft(uptime: 1010, now: now, bootID: "boot"), 1480)
        var changed = first; changed.focusMinutes = 10
        XCTAssertThrowsError(try book.save(changed))
    }
    func testEditingDurationAfterShortFocusCannotIncreaseEarnedCredit() throws {
        var book = QuestBook(); let short = Quest(title: "Short", focusMinutes: 1), next = Quest(title: "Next")
        try book.save(short); try book.save(next)
        _ = book.startFocus(short.id, uptime: 0, now: now, bootID: "boot")
        book.finishFocus(confirm: true, uptime: 60, now: now, bootID: "boot")
        _ = book.startFocus(next.id, uptime: 61, now: now, bootID: "boot")
        var changed = try XCTUnwrap(book.quests.first(where: { $0.id == short.id }))
        changed.focusMinutes = 25; changed.focusCreditMinutes = 25
        try book.save(changed); book.complete(short.id)
        XCTAssertEqual(book.xp, 20)
    }
    func testRestoredTimerAfterRebootNeedsConfirmationForCredit() throws {
        var book = QuestBook(); let quest = Quest(title: "Restored", focusMinutes: 10)
        try book.save(quest); _ = book.startFocus(quest.id, uptime: 100, now: now, bootID: "before")
        var restored = try QuestBook.restore(JSONEncoder().encode(book))
        XCTAssertEqual(restored.focus?.secondsLeft(uptime: 10, now: now.addingTimeInterval(1000), bootID: "after"), 0)
        XCTAssertFalse(restored.quests[0].focusFinished); XCTAssertEqual(restored.xp, 0)
        restored.finishFocus(confirm: true, uptime: 10, now: now.addingTimeInterval(1000), bootID: "after")
        XCTAssertTrue(restored.quests[0].focusFinished); XCTAssertNil(restored.quests[0].completedAt)
    }
    func testSavedPlaceRenamePreservesIdentityAndCoordinates() throws {
        let place = Place(id: "example", name: "Original", address: "Example town", coordinate: Coordinate(latitude: 51.5, longitude: 0), kind: "station", source: "Example provider")
        let named = try XCTUnwrap(place.renamed(" Work "))
        XCTAssertEqual(named.name, "Work"); XCTAssertEqual(named.id, place.id); XCTAssertEqual(named.coordinate, place.coordinate)
        XCTAssertEqual(named.address, place.address); XCTAssertEqual(named.source, place.source); XCTAssertEqual(named.kind, place.kind)
        XCTAssertNil(place.renamed(" ")); XCTAssertNil(place.renamed(String(repeating: "x", count: 81)))
        XCTAssertNil(place.renamed("bad\nname"))
    }
}
