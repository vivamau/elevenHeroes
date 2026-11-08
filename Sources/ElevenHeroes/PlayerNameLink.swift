import SwiftUI

struct PlayerNameLink: View {
    let id: Int
    let name: String
    var career: Season? = nil
    var player: Footballer? = nil
    var teamName: String = "Historical record"
    var label: String? = nil
    @State private var showing = false

    private var record: MarketPlayer? { career?.transferMarket.first { $0.id == id } }
    var body: some View {
        Button(label ?? name) { showing = true }
            .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
            .accessibilityLabel("View \(name)").help("View \(name)’s profile")
            .sheet(isPresented: $showing) {
                ScrollView {
                    PlayerDetailView(player: record?.player ?? player ?? career?.retiredPlayers?.first(where: { $0.id == id })?.player ?? Footballer(id: id, name: name, role: "—", rating: 0),
                                     career: career, teamName: record?.clubName ?? teamName, backLabel: "Back") { showing = false }
                        .padding(24)
                }.frame(width: 980, height: 730).background(AppTheme.background)
            }
    }
}

/// Older commentary stores names as text; only link an unambiguous player identity.
struct PlayerLinkedText: View {
    let text: String
    let career: Season
    @State private var selected: MarketPlayer?
    private var attributed: AttributedString {
        var result = AttributedString(text)
        let grouped = Dictionary(grouping: career.transferMarket, by: { $0.player.name })
        for (name, players) in grouped where players.count == 1 && !name.isEmpty {
            if let range = result.range(of: name) {
                result[range].link = URL(string: "eleven-player://profile/\(players[0].id)")
                result[range].foregroundColor = AppTheme.accent
            }
        }
        return result
    }
    var body: some View {
        Text(attributed).environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "eleven-player", let id = Int(url.lastPathComponent),
                  let player = career.transferMarket.first(where: { $0.id == id }) else { return .discarded }
            selected = player
            return .handled
        }).sheet(item: $selected) { entry in
            ScrollView {
                PlayerDetailView(player: entry.player, career: career, teamName: entry.clubName, backLabel: "Back") { selected = nil }.padding(24)
            }.frame(width: 980, height: 730).background(AppTheme.background)
        }
    }
}
