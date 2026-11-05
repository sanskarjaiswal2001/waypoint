import Darwin
import Foundation
import Observation
import WaypointKit

@MainActor @Observable final class QuestModel {
    private(set) var book = QuestBook()
    var problem: String?
    var lastCompleted: UUID?
    var now = Date()
    private let file: URL
    static let bootID: String = {
        var boot = timeval(), size = MemoryLayout<timeval>.size
        if sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 { return "\(boot.tv_sec):\(boot.tv_usec)" }
        return UUID().uuidString
    }()
    init(directory: URL? = nil) {
        var directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-waypoint-ui-testing") {
            directory = directory.appendingPathComponent("UITests")
            if !ProcessInfo.processInfo.arguments.contains("-waypoint-preserve-preferences") { try? FileManager.default.removeItem(at: directory) }
        }
        #endif
        file = directory.appendingPathComponent("waypoint-quests.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do { book = try QuestBook.restore(Data(contentsOf: file)) }
            catch { problem = "Saved quests could not be read. The stored file has been kept." }
        }
    }
    @discardableResult func change(_ edit: (inout QuestBook) throws -> Void) -> Bool {
        guard problem == nil else { return false }
        var next = book
        do {
            try edit(&next)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(next)
            _ = try QuestBook.restore(data)
            try data.write(to: file, options: .atomic)
            book = next
            return true
        } catch { problem = "The quest change could not be saved. Your previous quests have been kept."; return false }
    }
    func save(_ quest: Quest) -> Bool { change { try $0.save(quest) } }
    func complete(_ id: UUID) { if change({ $0.complete(id) }) { lastCompleted = id } }
    func undo(_ id: UUID) { if change({ $0.reopen(id) }) { lastCompleted = nil } }
    func delete(_ id: UUID) { if change({ $0.delete(id) }) && lastCompleted == id { lastCompleted = nil } }
    func startFocus(_ id: UUID) {
        _ = change { _ = $0.startFocus(id, uptime: ElapsedClock.now, now: Date(), bootID: Self.bootID) }
    }
    var focusSeconds: Int {
        Int(ceil(book.focus?.secondsLeft(uptime: ElapsedClock.now, now: now, bootID: Self.bootID) ?? 0))
    }
    func pauseFocus() { _ = change { $0.focus?.pause(uptime: ElapsedClock.now, now: Date(), bootID: Self.bootID) } }
    func resumeFocus() { _ = change { $0.focus?.resume(uptime: ElapsedClock.now, now: Date(), bootID: Self.bootID) } }
    func finishFocus(_ confirmed: Bool) { _ = change { $0.finishFocus(confirm: confirmed, uptime: ElapsedClock.now, now: Date(), bootID: Self.bootID) } }
}
