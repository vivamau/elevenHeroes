import SwiftUI

enum TeamKits {
    static let palette = [
        ("#E53935", "#FAFAFA"), ("#1565C0", "#FFD54F"),
        ("#6A1B9A", "#80DEEA"), ("#F57C00", "#172554"),
        ("#212121", "#F5F5F5"), ("#AD1457", "#FFF59D"),
        ("#00838F", "#FFCCBC"), ("#FDD835", "#283593")
    ]

    static func generated<R: RandomNumberGenerator>(using rng: inout R) -> (String, String) {
        palette[Int.random(in: palette.indices, using: &rng)]
    }

    static func fallback(id: Int) -> (String, String) { palette[Int(id.magnitude % UInt(palette.count))] }

    static func rgb(_ hex: String) -> (Double, Double, Double)? {
        let text = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return (Double((value >> 16) & 255) / 255, Double((value >> 8) & 255) / 255, Double(value & 255) / 255)
    }

    static func color(_ hex: String) -> Color {
        let rgb = rgb(hex) ?? (1, 1, 1)
        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }

    static func difference(_ first: String, _ second: String) -> Double {
        guard let a = rgb(first), let b = rgb(second) else { return 0 }
        return sqrt(pow(a.0 - b.0, 2) + pow(a.1 - b.1, 2) + pow(a.2 - b.2, 2))
    }

    static func select(home: Club, away: Club) -> (String, String) {
        let h = home.kitColors, a = away.kitColors
        // Prefer home primary, changing away shirts first when primary colours clash.
        if difference(h.0, a.0) >= 0.8 { return (h.0, a.0) }
        if difference(h.0, a.1) >= 0.8 { return (h.0, a.1) }
        return [(h.0, a.0), (h.0, a.1), (h.1, a.0), (h.1, a.1)]
            .max { difference($0.0, $0.1) < difference($1.0, $1.1) } ?? (h.0, a.1)
    }

    static func goalkeeper(home: String, away: String) -> Color {
        let choices = ["#FF9800", "#E040FB", "#FFFFFF", "#00E5FF", "#212121"]
        let best = choices.max { min(difference($0, home), difference($0, away)) < min(difference($1, home), difference($1, away)) }
        return color(best ?? "#FFFFFF")
    }
}

extension Club {
    var kitColors: (String, String) {
        let fallback = TeamKits.fallback(id: id)
        return (teamColorPrimary.flatMap { TeamKits.rgb($0) == nil ? nil : $0 } ?? fallback.0,
                teamColorSecondary.flatMap { TeamKits.rgb($0) == nil ? nil : $0 } ?? fallback.1)
    }
}
