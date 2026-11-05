import Foundation

public struct WorldVoice: Codable, Hashable, Sendable {
    public let openings: [String]
    public let cues: [String]
    public let arrivals: [String]
    public let rate: Double
    public let pitch: Double
    public init(openings: [String], cues: [String], arrivals: [String], rate: Double = 1, pitch: Double = 1) {
        self.openings = openings; self.cues = cues; self.arrivals = arrivals; self.rate = rate; self.pitch = pitch
    }
}

public struct WorldVoiceNarrator {
    private var introduced = false
    private var lastFlavour: TimeInterval?
    private var variations = [String: Int]()
    public init() {}
    public mutating func reset() { introduced = false; lastFlavour = nil }
    public mutating func decorate(_ text: String, distance: Double, world: String, voice: WorldVoice, at now: TimeInterval) -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        let arrival = text.range(of: #"^(you have |you've )?(arrived|reached your destination)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        let urgent = text.range(of: #"\b(now|immediately|recalculating|rerouting)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        if !arrival && (!distance.isFinite || distance < 120 || urgent || text.count > 180 || lastFlavour.map({ now - $0 < 45 }) == true) { return text }
        let moment = arrival ? 2 : introduced ? 1 : 0
        let choices = moment == 2 ? voice.arrivals : moment == 1 ? voice.cues : voice.openings
        guard !choices.isEmpty else { return text }
        let key = world + ":" + String(moment)
        let index = variations[key, default: 0] % choices.count
        variations[key] = (index + 1) % choices.count
        introduced = true; lastFlavour = now
        if variations.count > 256 { variations = [key: variations[key]!] }
        return text + (text.trimmingCharacters(in: .whitespacesAndNewlines).last.map { ".!?".contains($0) } == true ? " " : ". ") + choices[index]
    }
}
