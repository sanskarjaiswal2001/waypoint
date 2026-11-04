import SwiftUI

struct World: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let accentHex: String
    let routeHex: String
    let groundHex: String

    var accent: Color { Color(hex: accentHex) }
    var routeColor: UIColor { UIColor(hex: routeHex) }

    static let all: [World] = {
        guard let url = Bundle.main.url(forResource: "worlds", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let worlds = try? JSONDecoder().decode([World].self, from: data), !worlds.isEmpty else {
            preconditionFailure("The world catalogue is missing. Run scripts/prepare_ios.py before building.")
        }
        return worlds
    }()

    func styleJSON() throws -> String {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "styles") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

extension UIColor {
    convenience init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: CGFloat((value >> 16) & 255) / 255,
                  green: CGFloat((value >> 8) & 255) / 255,
                  blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}
