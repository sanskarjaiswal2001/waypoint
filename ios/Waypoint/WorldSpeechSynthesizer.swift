import AVFoundation
import FerrostarCore
import WaypointKit

final class WorldSpeechSynthesizer: SpeechSynthesizer {
    private let synthesizer = AVSpeechSynthesizer()
    private var narrator = WorldVoiceNarrator()
    private let context: @MainActor () -> (World, Double, Bool, Bool)
    private let lock = NSLock()
    private var generation = 0
    init(context: @escaping @MainActor () -> (World, Double, Bool, Bool)) { self.context = context }
    var isSpeaking: Bool { Thread.isMainThread ? synthesizer.isSpeaking : DispatchQueue.main.sync { synthesizer.isSpeaking } }
    func speak(_ utterance: AVSpeechUtterance) {
        let ticket = lock.withLock { generation }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let current = self.lock.withLock { self.generation }
            guard ticket == current else { return }
            let (world, distance, enabled, imperial) = self.context()
            let instruction = GuidanceSpeech.usingUnits(utterance.speechString, imperial: imperial)
            let text: String
            if enabled, let voice = world.voice {
                text = self.narrator.decorate(instruction, distance: distance, world: world.id, voice: voice, at: ElapsedClock.now)
            } else { text = instruction }
            let spoken = AVSpeechUtterance(string: text)
            spoken.voice = utterance.voice
            spoken.rate = AVSpeechUtteranceDefaultSpeechRate * Float(enabled ? world.voice?.rate ?? 1 : 1)
            spoken.pitchMultiplier = Float(enabled ? world.voice?.pitch ?? 1 : 1)
            self.synthesizer.speak(spoken)
        }
    }
    @discardableResult func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        lock.withLock { generation += 1 }
        if Thread.isMainThread { narrator.reset(); return synthesizer.stopSpeaking(at: boundary) }
        return DispatchQueue.main.sync { narrator.reset(); return synthesizer.stopSpeaking(at: boundary) }
    }
}
