import SwiftUI

/// Shared visual foundation for the game, database browser and its editors.
enum AppTheme {
    static let background = Color(red: 0.055, green: 0.075, blue: 0.09)
    static let panel = Color(red: 0.09, green: 0.115, blue: 0.13)
    static let accent = Color(red: 0.76, green: 0.96, blue: 0.35)
    static let panelRadius: CGFloat = 14
}

struct GameBrand: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "soccerball").font(.system(size: 29)).foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text("ELEVEN")
                Text("HEROES").foregroundStyle(AppTheme.accent)
            }.font(.system(size: 19, weight: .black, design: .rounded))
        }.accessibilityElement(children: .combine)
    }
}

struct SectionCaption: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased()).font(.system(size: 10, weight: .bold))
            .tracking(2).foregroundStyle(.secondary)
    }
}

extension View {
    func gamePrimaryAction() -> some View {
        buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background)
    }
}
