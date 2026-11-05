import Foundation
import XCTest
@testable import WaypointKit

final class PlaceSearchTests: XCTestCase {
    private let near = Coordinate(latitude: 51.5, longitude: -0.12)
    private func place(_ id: String = "station", name: String = "Riverton Railway Station", point: Coordinate? = nil, kind: String = "station") -> Place {
        Place(id: id, name: name, address: "Example town", coordinate: point ?? near, kind: kind)
    }
    func testStrongStationMatchRemovesUnrelatedPlaces() {
        let station = place()
        let farm = place("farm", name: "Riverton Research Centre", kind: "farmland")
        XCTAssertEqual(PlaceMatcher.ranked("Riverton Railway Station", near: near, places: [farm, station]), [station])
    }
    func testDiacriticsTyposJoinedNamesAndCategoryQueries() {
        let cafe = place("cafe", name: "Café Monde", kind: "cafe")
        XCTAssertEqual(PlaceMatcher.ranked("cafe monde", near: near, places: [cafe]), [cafe])
        XCTAssertEqual(PlaceMatcher.ranked("coffee", near: near, places: [cafe]), [cafe])
        let junction = place("junction", name: "Willow More", kind: "place")
        XCTAssertGreaterThan(PlaceMatcher.score("Willovmore", junction), 0.7)
        XCTAssertEqual(PlaceMatcher.variants(" Willovmore  "), ["Willovmore", "Willov more"])
    }
    func testRankingUsesDistanceAndMergesProviders() {
        let close = place(), far = place("far", point: Coordinate(latitude: 52, longitude: -0.12))
        let duplicate = place("other-provider")
        XCTAssertEqual(PlaceMatcher.ranked("Riverton Railway Station", near: near, places: [far, close, duplicate]), [close, far])
        XCTAssertTrue(PlaceMatcher.ranked("Riverton", near: near, places: [place(point: Coordinate(latitude: .nan, longitude: 0))]).isEmpty)
    }
    func testFallbackCachesSuccessAndIncludesCurrentLocalPlaces() async throws {
        let station = place()
        let calls = Calls()
        let search = PlaceSearch(primary: { _, _ in [] }, fallback: { _, _ in await calls.add(); return [station] })
        let first = try await search.search("Riverton Railway Station", near: near)
        XCTAssertEqual(first.places, [station])
        _ = try await search.search("Riverton Railway Station", near: near)
        let count = await calls.count
        XCTAssertEqual(count, 1)
        let local = place("saved", name: "Riverton Station", point: Coordinate(latitude: 51.51, longitude: -0.12))
        let cached = try await search.search("Riverton Railway Station", near: near, local: [local])
        XCTAssertTrue(cached.places.contains(local))
    }
    func testStrongPrimaryAvoidsFallbackUnlessExpanded() async throws {
        let station = place(), calls = Calls()
        let search = PlaceSearch(primary: { _, _ in [station] }, fallback: { _, _ in await calls.add(); return [] })
        _ = try await search.search("Riverton Station", near: near)
        var count = await calls.count
        XCTAssertEqual(count, 0)
        _ = try await search.search("Riverton Station", near: near, expanded: true)
        count = await calls.count
        XCTAssertEqual(count, 1)
    }
    func testWeakCachedMatchesRetainTheirWarning() async throws {
        let station = place()
        let search = PlaceSearch(primary: { _, _ in [station] })
        for _ in 0..<2 {
            let result = try await search.search("Rivertam", near: near)
            XCTAssertEqual(result.places, [station])
            XCTAssertTrue(result.note?.contains("Possible matches") == true)
        }
    }
    func testOutageKeepsFallbackAndLocalMatchesWithoutCachingFailure() async throws {
        let station = place(), calls = Calls()
        let search = PlaceSearch(primary: { _, _ in await calls.add(); throw URLError(.notConnectedToInternet) }, fallback: { _, _ in [station] })
        for _ in 0..<2 {
            let result = try await search.search("Riverton Station", near: near)
            XCTAssertEqual(result.places, [station]); XCTAssertNotNil(result.note)
        }
        let count = await calls.count
        XCTAssertEqual(count, 2)
        let offline = PlaceSearch(primary: { _, _ in throw URLError(.notConnectedToInternet) })
        let local = try await offline.search("Riverton Station", near: near, local: [station])
        XCTAssertEqual(local.places, [station])
    }
    func testTimeoutReachesFallbackAndCancellationNeverReachesIt() async throws {
        let station = place(), calls = Calls()
        let search = PlaceSearch(primary: { _, _ in try await Task.sleep(for: .seconds(60)); return [] },
                                 fallback: { _, _ in await calls.add(); return [station] }, timeout: .milliseconds(10))
        let result = try await search.search("Riverton Station", near: near)
        XCTAssertEqual(result.places, [station]); XCTAssertNotNil(result.note)
        let task = Task { try await search.search("Riverton Station", near: near, expanded: true) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled search returned results") } catch { XCTAssertTrue(error is CancellationError) }
        let count = await calls.count
        XCTAssertEqual(count, 1)
    }
    func testInFlightCancellationDoesNotPopulateCacheOrCallFallback() async throws {
        let entered = Calls(), fallback = Calls()
        let search = PlaceSearch(primary: { _, _ in await entered.add(); try await Task.sleep(for: .seconds(60)); return [] },
                                 fallback: { _, _ in await fallback.add(); return [] })
        for _ in 0..<2 {
            let target = await entered.count + 1
            let task = Task { try await search.search("Riverton", near: near) }
            while await entered.count < target { await Task.yield() }
            task.cancel()
            do { _ = try await task.value; XCTFail("Cancelled search returned") } catch { XCTAssertTrue(error is CancellationError) }
        }
        let count = await fallback.count
        XCTAssertEqual(count, 0)
    }
    func testCacheIsBoundedAndSearchAreasAreDistinct() async throws {
        let calls = Calls()
        let search = PlaceSearch(primary: { _, _ in await calls.add(); return [] })
        for index in 0..<41 { _ = try await search.search("Example \(index)", near: near) }
        _ = try await search.search("Example 0", near: near)
        _ = try await search.search("Example 0", near: Coordinate(latitude: 52, longitude: 0))
        let count = await calls.count
        XCTAssertEqual(count, 43)
    }
    func testAliasesAreExplicitBoundedAndKeepProviderCoordinates() async throws {
        let aliases = SearchAliases(["Willovmore": "Willow More", "": "Invalid", "Control": "bad\nname", "Long": String(repeating: "a", count: 257)])
        XCTAssertEqual(aliases.resolve("WILLOVMORE"), "Willow More")
        XCTAssertEqual(aliases.resolve("Control"), "Control")
        XCTAssertEqual(aliases.resolve("Long"), "Long")
        XCTAssertEqual(SearchAliases().resolve("Willovmore"), "Willovmore")
        let junction = place("junction", name: "Willow More", kind: "geocoder")
        let search = PlaceSearch(primary: { query, _ in XCTAssertEqual(query, "Willow More"); return [junction] }, aliases: aliases)
        let result = try await search.search("Willovmore", near: near)
        XCTAssertEqual(result.places, [junction]); XCTAssertEqual(result.note, "Searching for Willow More")
    }
    func testExcessiveInputNeverReachesProviders() async {
        let calls = Calls(), search = PlaceSearch(primary: { _, _ in await calls.add(); return [] })
        do { _ = try await search.search(String(repeating: "a", count: 257), near: near); XCTFail("Accepted long query") } catch {}
        let count = await calls.count
        XCTAssertEqual(count, 0)
    }
    func testExistingSavedPlacesDecodeWithoutSearchMetadata() throws {
        let old = Data(#"{"id":"old","name":"Example","address":"Example town","coordinate":{"latitude":51.5,"longitude":0}}"#.utf8)
        let place = try JSONDecoder().decode(Place.self, from: old)
        XCTAssertEqual(place.kind, "place"); XCTAssertEqual(place.source, "")
        XCTAssertEqual(try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(place)), place)
    }
}

private actor Calls {
    var count = 0
    func add() { count += 1 }
}
