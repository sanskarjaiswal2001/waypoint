import Foundation

public struct Quest: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var notes: String
    public var place: Place?
    public var focusMinutes: Int
    public var focusFinished: Bool
    public var focusCreditMinutes: Int? = nil
    public var completedAt: Date?
    public init(id: UUID = UUID(), title: String, notes: String = "", place: Place? = nil, focusMinutes: Int = 25) {
        self.id = id; self.title = title; self.notes = notes; self.place = place
        self.focusMinutes = focusMinutes; focusFinished = false
    }
}

public struct QuestReward: Codable, Equatable, Sendable {
    public let questID: UUID
    public let focused: Bool
    public var xp: Int { 20 + (focused ? 10 : 0) }
}

public struct FocusClock: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case running, paused, needsConfirmation, finished }
    public let questID: UUID
    public var remaining: TimeInterval
    public var startedUptime: TimeInterval
    public var deadline: Date
    public var bootID: String
    public var status: Status
    public init(questID: UUID, seconds: TimeInterval, uptime: TimeInterval, now: Date, bootID: String) {
        self.questID = questID; remaining = seconds; startedUptime = uptime
        deadline = now.addingTimeInterval(seconds); self.bootID = bootID; status = .running
    }
    public func secondsLeft(uptime: TimeInterval, now: Date, bootID: String) -> TimeInterval {
        guard status == .running else { return max(0, remaining) }
        if self.bootID == bootID { return max(0, remaining - max(0, uptime - startedUptime)) }
        return max(0, min(remaining, deadline.timeIntervalSince(now)))
    }
    public mutating func pause(uptime: TimeInterval, now: Date, bootID: String) {
        remaining = secondsLeft(uptime: uptime, now: now, bootID: bootID)
        status = remaining == 0 ? .needsConfirmation : .paused
    }
    public mutating func resume(uptime: TimeInterval, now: Date, bootID: String) {
        guard status == .paused else { return }
        startedUptime = uptime; deadline = now.addingTimeInterval(remaining); self.bootID = bootID; status = .running
    }
}

public struct QuestBook: Codable, Equatable, Sendable {
    public private(set) var quests = [Quest]()
    public private(set) var rewards = [QuestReward]()
    public var focus: FocusClock?
    public var showProgress = true
    public init() {}
    public var xp: Int { rewards.reduce(0) { $0 + $1.xp } }
    public var level: Int { 1 + xp / 100 }
    public var focusedCount: Int { rewards.filter(\.focused).count }
    public static func title(_ value: String, limit: Int = 160) -> String? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= limit, !cleaned.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return nil }
        return cleaned
    }
    public mutating func save(_ quest: Quest) throws {
        guard let title = Self.title(quest.title), quest.notes.count <= 2000, (1...180).contains(quest.focusMinutes), quest.place?.coordinate.isValid != false else { throw ServiceError.invalidResponse }
        var quest = quest; quest.title = title
        if let index = quests.firstIndex(where: { $0.id == quest.id }) {
            quest.completedAt = quests[index].completedAt
            quest.focusFinished = quests[index].focusFinished
            quest.focusCreditMinutes = quests[index].focusCreditMinutes
            guard focus?.questID != quest.id || quests[index].focusMinutes == quest.focusMinutes else { throw ServiceError.invalidResponse }
            quests[index] = quest
        } else {
            guard quests.count < 500 else { throw ServiceError.tooLarge }
            quest.completedAt = nil; quest.focusFinished = false; quest.focusCreditMinutes = nil; quests.insert(quest, at: 0)
        }
    }
    @discardableResult public mutating func complete(_ id: UUID, at now: Date = Date()) -> Bool {
        guard let index = quests.firstIndex(where: { $0.id == id }), quests[index].completedAt == nil else { return false }
        quests[index].completedAt = now
        if !rewards.contains(where: { $0.questID == id }) { rewards.append(QuestReward(questID: id, focused: quests[index].focusFinished && (quests[index].focusCreditMinutes ?? 0) >= 10)) }
        if focus?.questID == id { focus = nil }
        return true
    }
    public mutating func reopen(_ id: UUID) {
        guard let index = quests.firstIndex(where: { $0.id == id }) else { return }
        quests[index].completedAt = nil
        rewards.removeAll { $0.questID == id }
    }
    public mutating func delete(_ id: UUID) {
        quests.removeAll { $0.id == id }
        if focus?.questID == id { focus = nil }
    }
    public mutating func startFocus(_ id: UUID, uptime: TimeInterval, now: Date, bootID: String) -> Bool {
        guard focus == nil || focus?.status == .finished,
              let quest = quests.first(where: { $0.id == id }), quest.completedAt == nil else { return false }
        focus = FocusClock(questID: id, seconds: Double(quest.focusMinutes * 60), uptime: uptime, now: now, bootID: bootID)
        return true
    }
    public mutating func finishFocus(confirm: Bool, uptime: TimeInterval, now: Date, bootID: String) {
        guard var clock = focus else { return }
        let expired = clock.secondsLeft(uptime: uptime, now: now, bootID: bootID) == 0
        guard expired, confirm else { focus = nil; return }
        clock.remaining = 0; clock.status = .finished; focus = clock
        if let index = quests.firstIndex(where: { $0.id == clock.questID }) { quests[index].focusFinished = true; quests[index].focusCreditMinutes = quests[index].focusMinutes }
    }
    public static func restore(_ data: Data) throws -> Self {
        guard data.count <= 2_000_000 else { throw ServiceError.tooLarge }
        let book = try JSONDecoder().decode(Self.self, from: data)
        guard book.quests.count <= 500, book.rewards.count <= 100_000,
              Set(book.quests.map(\.id)).count == book.quests.count,
              Set(book.rewards.map(\.questID)).count == book.rewards.count,
              book.quests.allSatisfy({ title($0.title) != nil && $0.notes.count <= 2000 && (1...180).contains($0.focusMinutes) && $0.place?.coordinate.isValid != false }) else { throw ServiceError.invalidResponse }
        if let focus = book.focus {
            guard book.quests.contains(where: { $0.id == focus.questID }), focus.remaining.isFinite, (0...10_800).contains(focus.remaining), focus.startedUptime.isFinite, focus.startedUptime >= 0 else { throw ServiceError.invalidResponse }
        }
        return book
    }
}
