import Foundation

/// Adapts the public OSRM-compatible endpoints to Ferrostar's banner and speech format.
public enum RoutePreparation {
    public static func prepare(_ data: Data, expectedOrigin: Coordinate? = nil, expectedDestination: Coordinate? = nil) throws -> Data {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["code"] as? String == "Ok",
              var route = (root["routes"] as? [[String: Any]])?.first,
              let distance = route["distance"] as? Double, distance > 0, distance <= 40_000_000,
              let duration = route["duration"] as? Double, duration >= 0, duration <= 31 * 86400,
              let geometry = route["geometry"] as? String, geometry.count <= 1_000_000,
              var legs = route["legs"] as? [[String: Any]], (1...64).contains(legs.count) else {
            throw ServiceError.noRoute
        }
        let points = try decodePolyline6(geometry)
        guard (2...50_000).contains(points.count) else { throw ServiceError.invalidResponse }
        if let expectedOrigin, expectedOrigin.distance(to: points[0]) > 1500 { throw ServiceError.noRoute }
        if let expectedDestination, expectedDestination.distance(to: points[points.count - 1]) > 1500 { throw ServiceError.noRoute }
        var allSteps = [[String: Any]]()
        var legSizes = [Int]()
        for leg in legs {
            guard let steps = leg["steps"] as? [[String: Any]], !steps.isEmpty else { throw ServiceError.invalidResponse }
            legSizes.append(steps.count)
            allSteps += steps
            guard allSteps.count <= 2_000, allSteps.count * points.count <= 10_000_000 else { throw ServiceError.tooLarge }
        }
        for index in allSteps.indices {
            guard let distance = allSteps[index]["distance"] as? Double, distance >= 0, distance <= 40_000_000,
                  let duration = allSteps[index]["duration"] as? Double, duration >= 0, duration <= 31 * 86400,
                  let maneuver = allSteps[index]["maneuver"] as? [String: Any],
                  let point = maneuver["location"] as? [Double], point.count == 2,
                  Coordinate(latitude: point[1], longitude: point[0]).isValid else { throw ServiceError.invalidResponse }
            let next = allSteps[min(index + 1, allSteps.count - 1)]
            let instruction = instruction(for: next)
            var currentManeuver = maneuver
            if (currentManeuver["instruction"] as? String)?.isEmpty != false {
                currentManeuver["instruction"] = Self.instruction(for: allSteps[index])
                allSteps[index]["maneuver"] = currentManeuver
            }
            if (allSteps[index]["voiceInstructions"] as? [Any])?.isEmpty != false {
                var voice = [[String: Any]]()
                if distance > 210 {
                    voice.append(["announcement": "In 180 metres, \(instruction)", "distanceAlongGeometry": 180.0])
                }
                if distance > 45 {
                    voice.append(["announcement": instruction, "distanceAlongGeometry": 35.0])
                }
                allSteps[index]["voiceInstructions"] = voice
            }
            if (allSteps[index]["bannerInstructions"] as? [Any])?.isEmpty != false {
                allSteps[index]["bannerInstructions"] = [[
                    "distanceAlongGeometry": min(distance, 300),
                    "primary": ["text": instruction, "components": [["type": "text", "text": instruction]]]
                ]]
            } else if var banners = allSteps[index]["bannerInstructions"] as? [[String: Any]] {
                for banner in banners.indices {
                    for key in ["primary", "secondary", "sub"] {
                        if var content = banners[banner][key] as? [String: Any], content["components"] == nil {
                            content["components"] = []
                            banners[banner][key] = content
                        }
                    }
                }
                allSteps[index]["bannerInstructions"] = banners
            }
        }
        var offset = 0
        for index in legs.indices {
            legs[index]["steps"] = Array(allSteps[offset..<(offset + legSizes[index])])
            offset += legSizes[index]
        }
        route["legs"] = legs
        return try JSONSerialization.data(withJSONObject: route)
    }

    public static func instruction(for step: [String: Any]) -> String {
        let maneuver = step["maneuver"] as? [String: Any] ?? [:]
        let type = maneuver["type"] as? String ?? "continue"
        let modifier = clean(maneuver["modifier"] as? String ?? "")
        let road = clean(step["name"] as? String ?? "")
        let onto = road.isEmpty ? "" : " onto \(road)"
        switch type {
        case "arrive": return "You have arrived at your destination"
        case "depart": return "Head \(modifier.isEmpty ? "along the road" : modifier)\(onto)"
        case "roundabout", "rotary":
            if let exit = maneuver["exit"] as? Int, (1...99).contains(exit) {
                return "At the roundabout, take exit \(exit)\(onto)"
            }
            return "Enter the roundabout\(onto)"
        case "merge": return "Merge \(modifier)\(onto)"
        case "fork": return "Keep \(modifier)\(onto)"
        case "turn", "end of road": return "Turn \(modifier)\(onto)"
        default: return "Continue\(modifier.isEmpty ? "" : " \(modifier)")\(onto)"
        }
    }

    public static func decodePolyline6(_ encoded: String) throws -> [Coordinate] {
        let bytes = Array(encoded.utf8)
        var cursor = 0
        var latitude: Int64 = 0
        var longitude: Int64 = 0
        func value() throws -> Int64 {
            var result: Int64 = 0
            var shift = 0
            while true {
                guard cursor < bytes.count, shift <= 35, (63...126).contains(bytes[cursor]) else {
                    throw ServiceError.invalidResponse
                }
                let chunk = Int64(bytes[cursor]) - 63
                cursor += 1
                result |= (chunk & 31) << shift
                if chunk < 32 { break }
                shift += 5
            }
            return result & 1 == 0 ? result >> 1 : -(result >> 1) - 1
        }
        var coordinates = [Coordinate]()
        while cursor < bytes.count {
            guard coordinates.count < 50_000 else { throw ServiceError.tooLarge }
            latitude += try value()
            longitude += try value()
            let point = Coordinate(latitude: Double(latitude) / 1_000_000, longitude: Double(longitude) / 1_000_000)
            guard point.isValid else { throw ServiceError.invalidCoordinate }
            coordinates.append(point)
        }
        return coordinates
    }
}
