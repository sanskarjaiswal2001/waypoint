import XCTest
@testable import WaypointKit

final class WorldVoiceTests: XCTestCase {
    private let voice = WorldVoice(openings: ["Opening one.", "Opening two."], cues: ["Next cue."], arrivals: ["Arrival line."])
    func testUsefulInstructionIsPreservedAndFlavourIsSuppressedNearTurns() {
        var narrator = WorldVoiceNarrator()
        let instruction = "In 600 feet, turn left onto Example Road"
        XCTAssertEqual(narrator.decorate(instruction, distance: 180, world: "example", voice: voice, at: 0), instruction + ". Opening one.")
        XCTAssertEqual(narrator.decorate(instruction, distance: 35, world: "example", voice: voice, at: 50), instruction)
        XCTAssertEqual(narrator.decorate("Turn right now", distance: 180, world: "example", voice: voice, at: 60), "Turn right now")
        XCTAssertEqual(narrator.decorate(instruction, distance: 180, world: "example", voice: voice, at: 20), instruction)
        XCTAssertEqual(narrator.decorate(instruction, distance: 180, world: "example", voice: voice, at: 60), instruction + ". Next cue.")
    }
    func testRestartVariesOpeningAndArrivalDoesNotNeedDistance() {
        var narrator = WorldVoiceNarrator()
        _ = narrator.decorate("Head north", distance: 180, world: "example", voice: voice, at: 0)
        narrator.reset()
        XCTAssertEqual(narrator.decorate("Head north", distance: 180, world: "example", voice: voice, at: 1), "Head north. Opening two.")
        XCTAssertEqual(narrator.decorate("You have arrived at your destination", distance: 0, world: "example", voice: voice, at: 2), "You have arrived at your destination. Arrival line.")
    }
    func testUnitPreferenceCanChangeAfterRoutePreparation() {
        XCTAssertEqual(GuidanceSpeech.usingUnits("In 180 metres, Turn left onto Example Road", imperial: true), "In 600 feet, Turn left onto Example Road")
        XCTAssertEqual(GuidanceSpeech.usingUnits("In 600 feet, Turn left onto Example Road", imperial: false), "In 180 metres, Turn left onto Example Road")
        XCTAssertEqual(GuidanceSpeech.usingUnits("Turn right onto 180 Metres Road", imperial: true), "Turn right onto 180 Metres Road")
    }
}
