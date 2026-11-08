import SwiftUI

struct PlayerProfile: Codable, Hashable {
    let values: [String: String]
    let birthCity: String
    let foot: String
    let morale: String
}

extension FootballDatabase {
    func playerProfiles() throws -> [Int: PlayerProfile] {
        let positions = try primaryPositions()
        let cities = try records(.city)
        let choices = try attributeChoices()
        return Dictionary(uniqueKeysWithValues: try records(.player).map { record in
            var values = record.values
            values["position_name"] = positions[record.id]
            return (record.id, PlayerProfile(values: values,
                birthCity: cities.first { String($0.id) == record.values["city_id"] }?.title ?? "Not recorded",
                foot: choices["player_foot_id"]?.first { $0.id == record.values["player_foot_id"] }?.name ?? "Not recorded",
                morale: choices["player_morale_id"]?.first { $0.id == record.values["player_morale_id"] }?.name ?? "Not recorded"))
        })
    }
}

struct PlayerDetailView: View {
    let player: Footballer
    var career: Season? = nil
    var teamName: String
    var backLabel = "Back"
    var onTeam: (() -> Void)? = nil
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onBack) { Label(backLabel, systemImage: "chevron.left") }
                .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
            header
            if let career {
                PlayerEvaluationTrendView(playerID: player.id, season: career)
            }
            if let profile = player.profile {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        personal(profile).frame(minWidth: 240, maxWidth: .infinity)
                        PlayerStatsView(player: player, career: career).frame(minWidth: 320, maxWidth: .infinity)
                    }
                    VStack(spacing: 14) { personal(profile); PlayerStatsView(player: player, career: career) }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        attributes("Physical", PlayerAttributes.physical, profile).frame(minWidth: 250, maxWidth: .infinity)
                        attributes("Mental", PlayerAttributes.mental, profile).frame(minWidth: 310, maxWidth: .infinity)
                    }
                    VStack(spacing: 14) {
                        attributes("Physical", PlayerAttributes.physical, profile)
                        attributes("Mental", PlayerAttributes.mental, profile)
                    }
                }
            } else {
                PlayerStatsView(player: player, career: career)
                Label("Detailed attributes weren’t included in this career’s saved profile.", systemImage: "person.text.rectangle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Text("Skills: 1–20 · Condition: 0–100% · Overall uses physical attributes · —: not recorded")
                .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var header: some View {
        HStack(spacing: 14) {
            Group {
                let parts = player.name.split(separator: " ", maxSplits: 1)
                let first = parts.first.map(String.init) ?? player.name
                let last = parts.count > 1 ? String(parts[1]) : ""
                if let image = CSVPlayerProfiles.image(for: first, last: last), let url = URL(string: image) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "person.fill").font(.system(size: 25)).foregroundStyle(AppTheme.accent)
                        }
                    }
                } else {
                    Image(systemName: "person.fill").font(.system(size: 25)).foregroundStyle(AppTheme.accent)
                }
            }.frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 14))
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(player.name).font(.system(size: 26, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(player.profile?.values["position_name"] ?? player.role).font(.caption.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    if let age = player.careerAge { Text("\(age) years").foregroundStyle(.secondary) }
                    if let onTeam {
                        Button(teamName, action: onTeam).buttonStyle(.plain).foregroundStyle(AppTheme.accent)
                            .help("View \(teamName) squad")
                    } else { Text(teamName).foregroundStyle(.secondary) }
                }.font(.subheadline)
                Label {
                    Text("Weekly wage · \(player.currentSalary.formatted()) credits")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "creditcard")
                }.font(.callout.weight(.medium)).foregroundStyle(AppTheme.accent)
                    .accessibilityLabel("Weekly wage: \(player.currentSalary) credits")
            }
            Spacer(minLength: 10)
            if player.rating > 0 {
                VStack(spacing: 2) {
                    Text("\(player.rating)").font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(AppTheme.accent)
                    Text("OVERALL").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
            }
        }
    }
    private func personal(_ profile: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionCaption("Personal information")
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 15) {
                fact("Date of birth", birthDate(profile))
                fact("Birth city", profile.birthCity)
                fact("Preferred foot", profile.foot)
                fact("Morale", profile.morale)
                fact("Position", profile.values["position_name"] ?? "Not recorded")
                fact("Condition", profile.values["player_skills_phys_condition"].map { "\($0)%" } ?? "Not recorded")
            }
        }.padding(16).frame(maxWidth: .infinity, minHeight: 222, alignment: .topLeading)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
    }
    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium)).lineLimit(2).help(value)
        }.accessibilityElement(children: .combine)
    }
    private func birthDate(_ profile: PlayerProfile) -> String {
        guard let raw = profile.values["player_dob"], let date = RecordDraft.dateFormatter.date(from: raw) else { return "Not recorded" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    private func attributes(_ title: String, _ attributes: [PlayerAttribute], _ profile: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(title)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible())], spacing: 0) {
                ForEach(attributes) { attribute in
                    HStack(spacing: 8) {
                        Text(attribute.label).foregroundStyle(.secondary).lineLimit(1).help(attribute.label)
                        Spacer(minLength: 0)
                        Text(profile.values[attribute.id].flatMap { $0.isEmpty ? nil : $0 } ?? "—")
                            .fontWeight(.semibold).monospacedDigit()
                    }.font(.callout).frame(height: 27)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(attribute.label)
                        .accessibilityValue(profile.values[attribute.id].map { "\($0) out of \(attribute.range.upperBound)" } ?? "Not recorded")
                }
            }
        }.padding(16).frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.panelRadius))
    }
}
