import SwiftUI

// Matches spec §5.4
struct ThemeColors: Hashable, Codable, Sendable {
    let base: String
    let mantle: String
    let crust: String
    let text: String
    let subtext0: String
    let subtext1: String
    let surface0: String
    let surface1: String
    let surface2: String
    let accent: String
    let link: String
}

extension ThemeColors {
    var baseColor: Color { Color(hex: base) }
    var mantleColor: Color { Color(hex: mantle) }
    var crustColor: Color { Color(hex: crust) }
    var textColor: Color { Color(hex: text) }
    var subtext0Color: Color { Color(hex: subtext0) }
    var subtext1Color: Color { Color(hex: subtext1) }
    var surface0Color: Color { Color(hex: surface0) }
    var surface1Color: Color { Color(hex: surface1) }
    var surface2Color: Color { Color(hex: surface2) }
    var accentColor: Color { Color(hex: accent) }
    var linkColor: Color { Color(hex: link) }

    var isDark: Bool {
        let stripped = base.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: stripped)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b < 0.5
    }

    static let mock = ThemeColors(
        base: "#1e1e2e", mantle: "#181825", crust: "#11111b",
        text: "#cdd6f4", subtext0: "#a6adc8", subtext1: "#bac2de",
        surface0: "#313244", surface1: "#45475a", surface2: "#585b70",
        accent: "#89b4fa", link: "#89b4fa"
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
