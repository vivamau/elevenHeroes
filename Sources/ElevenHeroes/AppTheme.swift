import SwiftUI

/// Shared visual foundation for the game, database browser and its editors.
enum AppTheme {
    static let background = Color(red: 0.055, green: 0.075, blue: 0.09)
    static let panel = Color(red: 0.09, green: 0.115, blue: 0.13)
    static let accent = Color(red: 0.76, green: 0.96, blue: 0.35)
    static let panelRadius: CGFloat = 14
    @MainActor static func sheetHeight(_ preferred: CGFloat) -> CGFloat {
        min(preferred, max(400, (NSScreen.main?.visibleFrame.height ?? 900) - 100))
    }
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
    nonisolated init(_ title: String) { self.title = title }
    var body: some View {
        Text(title).font(.headline).foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    func gamePrimaryAction() -> some View {
        buttonStyle(GameActionButtonStyle())
    }
}

struct GameCard<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionCaption(title)
            content
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).gameSurface()
    }
}

private struct GameSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content.background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                    .strokeBorder(.white.opacity(contrast == .increased ? 0.35 : 0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func gameSurface() -> some View { modifier(GameSurface()) }
}

/// One action-button shape and interaction language throughout the app.
struct GameActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let compact = controlSize == .small || controlSize == .mini
        let cancel = configuration.role == .cancel
        let fill = configuration.role == .destructive ? Color.red : cancel ? Color.white.opacity(0.12) : AppTheme.accent
        configuration.label
            .font(.system(size: compact ? 12 : 14, weight: .semibold))
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 6 : 10)
            .frame(minHeight: compact ? 30 : 40)
            .foregroundStyle(isEnabled ? (cancel ? Color.primary : AppTheme.background) : Color.secondary)
            .background(isEnabled ? fill.opacity(configuration.isPressed ? 0.72 : 1) : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(contrast == .increased ? 0.5 : 0.08), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
