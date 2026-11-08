import SwiftUI

struct CountryDetailView: View {
    let country: DatabaseRecord
    let leagues: [DatabaseRecord]
    let onLeague: (DatabaseRecord) -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: onBack) { Label("Back to countries", systemImage: "chevron.left") }
                .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
            HStack(spacing: 18) {
                Image(systemName: "globe").font(.system(size: 36)).foregroundStyle(AppTheme.accent)
                    .frame(width: 76, height: 76).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 8) {
                    Text(country.title).font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("\(country.values["country_iso3"] ?? "") · \(leagues.count) leagues")
                        .foregroundStyle(.secondary)
                }
            }
            if leagues.isEmpty {
                ContentUnavailableView("No leagues yet", systemImage: "trophy", description: Text("Open Leagues and create or edit a league to assign it to this country."))
            } else {
                VStack(spacing: 0) {
                    ForEach(leagues) { league in
                        Button { onLeague(league) } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "trophy").foregroundStyle(AppTheme.accent)
                                Text(league.title).fontWeight(.semibold).foregroundStyle(AppTheme.accent)
                                Spacer()
                                Text("\(league.values["championship_teams_number"] ?? "—") configured teams")
                                    .font(.callout).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(16).contentShape(Rectangle())
                        }.buttonStyle(.plain).help("View \(league.title)")
                        Divider()
                    }
                }.background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
