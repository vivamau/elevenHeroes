import SwiftUI

struct SquadTableView: View {
    let players: [Footballer]
    var lineup: [Int] = []
    var substitutes: [Int] = []
    var onToggle: ((Int) -> Void)? = nil
    let onPlayer: (Footballer) -> Void
    @State private var search = ""
    @State private var sortKey = "name"
    @State private var ascending = true

    private struct Column: Identifiable {
        let id: String
        let title: String
        let width: CGFloat
        var numeric = false
    }
    private var columns: [Column] {
        var result = [Column(id: "name", title: "Player", width: 220),
                      Column(id: "position", title: "Position", width: 90),
                      Column(id: "rating", title: "Overall", width: 80, numeric: true),
                      Column(id: "age", title: "Age", width: 65, numeric: true),
                      Column(id: "dob", title: "Date of birth", width: 130),
                      Column(id: "city", title: "Birth city", width: 180),
                      Column(id: "foot", title: "Foot", width: 100),
                      Column(id: "morale", title: "Morale", width: 110)]
        result += (PlayerAttributes.physical + PlayerAttributes.mental).map {
            Column(id: $0.id, title: $0.label, width: max(110, CGFloat($0.label.count * 8 + 30)), numeric: true)
        }
        return result
    }
    private func value(_ player: Footballer, _ key: String) -> String {
        switch key {
        case "name": return player.name
        case "position": return player.profile?.values["position_name"] ?? player.role
        case "rating": return String(player.rating)
        case "age": return player.careerAge.map(String.init) ?? "—"
        case "dob":
            guard let raw = player.profile?.values["player_dob"], let date = RecordDraft.dateFormatter.date(from: raw) else { return "—" }
            return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        case "city": return player.profile?.birthCity ?? "—"
        case "foot": return player.profile?.foot ?? "—"
        case "morale": return player.profile?.morale ?? "—"
        default:
            guard let raw = player.profile?.values[key], !raw.isEmpty else { return "—" }
            return raw
        }
    }
    private var visiblePlayers: [Footballer] {
        players.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || value($0, "position").localizedCaseInsensitiveContains(search) }
            .sorted { a, b in
                let left = sortKey == "dob" ? a.profile?.values["player_dob"] ?? "" : value(a, sortKey)
                let right = sortKey == "dob" ? b.profile?.values["player_dob"] ?? "" : value(b, sortKey)
                if left == right { return a.id < b.id }
                if columns.first(where: { $0.id == sortKey })?.numeric == true {
                    return ascending ? (Int(left) ?? -1) < (Int(right) ?? -1) : (Int(left) ?? -1) > (Int(right) ?? -1)
                }
                return ascending ? left.localizedStandardCompare(right) == .orderedAscending : left.localizedStandardCompare(right) == .orderedDescending
            }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search players or positions", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                Spacer()
                Text("\(visiblePlayers.count) players").font(.caption).foregroundStyle(.secondary)
            }
            Text("Scroll sideways for all attributes. Click a heading to sort. Skills: 1–20 · Condition: 0–100% · —: not recorded.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(visiblePlayers.enumerated()), id: \.element.id) { index, player in
                            HStack(spacing: 0) {
                                if let onToggle {
                                    Toggle("Select \(player.name) for starting XI", isOn: Binding(get: { lineup.contains(player.id) }, set: { _ in onToggle(player.id) }))
                                        .labelsHidden().toggleStyle(.checkbox).frame(width: 55)
                                        .disabled(!lineup.contains(player.id) && lineup.count >= 11)
                                }
                                ForEach(columns) { column in
                                    Group {
                                        if column.id == "name" {
                                            Button(player.name) { onPlayer(player) }.buttonStyle(.plain).foregroundStyle(AppTheme.accent).fontWeight(.medium)
                                        } else { Text(value(player, column.id)).monospacedDigit() }
                                    }.lineLimit(1).help(value(player, column.id))
                                        .frame(width: column.width - 24, alignment: column.numeric ? .trailing : .leading)
                                        .padding(.horizontal, 12)
                                }
                            }.frame(height: 40)
                                .background(lineup.contains(player.id) ? AppTheme.accent.opacity(0.09) : substitutes.contains(player.id) ? AppTheme.accent.opacity(0.035) : index.isMultiple(of: 2) ? AppTheme.panel : AppTheme.background)
                                .clipShape(Rectangle())
                            Divider()
                        }
                    } header: {
                        HStack(spacing: 0) {
                            if onToggle != nil { Text("XI").frame(width: 55) }
                            ForEach(columns) { column in
                                Button {
                                    if sortKey == column.id { ascending.toggle() } else { sortKey = column.id; ascending = !column.numeric }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(column.title)
                                        if sortKey == column.id { Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.system(size: 9)) }
                                    }.frame(width: column.width - 24, alignment: column.numeric ? .trailing : .leading).padding(.horizontal, 12).frame(height: 42)
                                }.buttonStyle(.plain).help("Sort by \(column.title)")
                            }
                        }.font(.caption.bold()).background(AppTheme.panel)
                    }
                }
            }.frame(height: 480)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
            if visiblePlayers.isEmpty { Text("No matching players.").foregroundStyle(.secondary) }
        }
    }
}
