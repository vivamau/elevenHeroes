import SwiftUI

struct MarketView: View {
    @Bindable var store: GameStore
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var search = ""
    @State private var selected: MarketPlayer?
    @State private var message: String?
    @State private var viewed: MarketPlayer?
    @State private var viewedTeam: Club?
    @State private var tab = MarketTab.buy
    private var yourTeam: Bool { tab == .team }
    private enum MarketTab { case buy, team, offers, withoutContract }
    @State private var sort = MarketSort.name

    private enum MarketSort: String, CaseIterable {
        case name = "Name", rating = "Highest rating", value = "Lowest price"
    }
    private var balance: Int { store.season?.credits ?? 0 }
    private var squadCount: Int { store.season?.squadCount ?? 0 }
    private var sellableCount: Int { max(0, squadCount - 16) }
    private var border: Color { .white.opacity(contrast == .increased ? 0.4 : 0.09) }
    private var listings: [MarketPlayer] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return (store.season?.transferMarket ?? []).filter {
            ($0.clubID == store.season?.selectedClub) == yourTeam && (query.isEmpty
                || $0.player.name.localizedCaseInsensitiveContains(query)
                || $0.clubName.localizedCaseInsensitiveContains(query)
                || position($0.player).localizedCaseInsensitiveContains(query))
        }.sorted {
            if sort == .rating, $0.player.rating != $1.player.rating { return $0.player.rating > $1.player.rating }
            if sort == .value, $0.player.creditsValue != $1.player.creditsValue { return $0.player.creditsValue < $1.player.creditsValue }
            let order = $0.player.name.localizedStandardCompare($1.player.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let club = viewedTeam {
                TeamDetailView(club: club, career: store.season, context: "Current career", backLabel: "Back to player") { viewedTeam = nil }
            } else if let viewed {
                PlayerDetailView(player: viewed.player, career: store.season, teamName: viewed.clubName, backLabel: "Back to market", onTeam: viewed.clubID.map { id in
                    {
                        viewedTeam = store.season?.clubs.first { $0.id == id }
                            ?? Club(id: id, name: viewed.clubName, city: "", players: (store.season?.transferMarket ?? []).filter { $0.clubID == id }.map(\.player))
                    }
                }) { self.viewed = nil }
            } else {
                summary
                if let message {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.accent)
                        Group { if let season = store.season { PlayerLinkedText(text: message, career: season) } else { Text(message) } }.font(.callout)
                        Spacer()
                        Button { self.message = nil } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Dismiss transfer confirmation")
                    }.padding(14).background(AppTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }
                marketTabs
                if tab == .offers {
                    IncomingOffersView(store: store, onPlayer: { viewed = $0 }, onComplete: { message = $0 })
                } else if tab == .withoutContract {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Players whose contracts have ended will appear here.", systemImage: "doc.text")
                            .font(.callout).foregroundStyle(.secondary)
                        Text("No out-of-contract players are currently available.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(20).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                } else { browser(listings) }
            }
        }
        .sheet(item: $selected) { offerSheet($0) }
    }

    private var summary: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Transfer budget", systemImage: "creditcard").font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(balance.formatted()).font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(AppTheme.accent)
                    Text("credits").font(.callout).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Divider().frame(height: 48)
            VStack(alignment: .leading, spacing: 8) {
                Text("Your squad").font(.subheadline).foregroundStyle(.secondary)
                Text("\(squadCount) players").font(.title3.weight(.semibold)).monospacedDigit()
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Label(sellableCount > 0 ? "Room to sell" : "Squad minimum", systemImage: sellableCount > 0 ? "arrow.up.right" : "lock")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(sellableCount > 0 ? "\(sellableCount) players" : "16 players required")
                    .font(.title3.weight(.semibold)).monospacedDigit()
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(22)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(border))
    }

    private var marketTabs: some View {
        HStack {
            Picker("Market section", selection: $tab) {
                Text("Buy players").tag(MarketTab.buy)
                Text("Your team").tag(MarketTab.team)
                Text("Offers (\(store.season?.pendingOffers.count ?? 0))").tag(MarketTab.offers)
                Text("Without contract").tag(MarketTab.withoutContract)
            }.pickerStyle(.segmented).labelsHidden().frame(width: 470).controlSize(.large)
                .onChange(of: tab) { _, _ in search = ""; message = nil }
            Spacer()
            Text(tab == .offers ? "Incoming bids" : "\(listings.count.formatted()) players")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func browser(_ entries: [MarketPlayer]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search players, clubs or positions", text: $search).textFieldStyle(.plain)
                        .accessibilityLabel("Search players, clubs or positions")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain).accessibilityLabel("Clear search")
                    }
                }.padding(.horizontal, 13).frame(height: 38)
                    .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(border))
                Picker("Sort", selection: $sort) {
                    ForEach(MarketSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.frame(width: 190).controlSize(.large)
            }
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(entries) { listing in
                                MarketPlayerRow(listing: listing, yourTeam: yourTeam, isListed: (store.season?.listedPlayerIDs ?? []).contains(listing.id),
                                    enabled: yourTeam ? !(store.season?.listedPlayerIDs ?? []).contains(listing.id) : listing.clubID != nil && listing.player.creditsValue <= balance,
                                    unavailableReason: yourTeam ? "This player is listed. Review bids in Offers." : listing.clubID == nil ? "Free-agent signings are not available yet." : "Not enough credits.",
                                    onPlayer: { viewed = listing }, onAction: {
                                        if yourTeam {
                                            if store.listPlayerForTransfer(listing.id) { message = "\(listing.player.name) is listed. Check Offers after the next matchweek." }
                                        }
                                        else { selected = listing }
                                    })
                                Divider().opacity(0.5).padding(.leading, 74)
                            }
                            if entries.isEmpty {
                                ContentUnavailableView {
                                    Label("No players found", systemImage: "magnifyingglass")
                                } description: {
                                    Text(search.isEmpty ? "There are no players in this list." : "Try another name, club or position.")
                                } actions: {
                                    if !search.isEmpty { Button("Clear search") { search = "" } }
                                }.frame(maxWidth: .infinity).padding(.vertical, 50)
                            }
                        } header: { columnHeadings }
                    }
                }.frame(height: 400)
                HStack(spacing: 8) {
                    Image(systemName: yourTeam ? "person.3" : "info.circle")
                    Text(yourTeam ? "List a player to invite bids. Accept or reject them in Offers; keep at least 16 players." : "Clubs may refuse offers for key players. A 5–20% premium can persuade them.")
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 12)
                    .background(.white.opacity(0.025))
            }.background(AppTheme.panel.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(border))
        }
    }

    private var columnHeadings: some View {
        HStack(spacing: 14) {
            Text("Player / Club").frame(maxWidth: .infinity, alignment: .leading)
            Text("Position").frame(width: 60)
            Text("Overall").frame(width: 56)
            Text("Value (cr)").frame(width: 80, alignment: .trailing)
            Text("Wage / week").frame(width: 100, alignment: .trailing)
            Text(yourTeam ? "Market" : "Buy").frame(width: 100, alignment: .trailing)
        }.font(.caption.weight(.medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            .padding(.horizontal, 18).padding(.vertical, 13)
            .background {
                if reduceTransparency || contrast == .increased { AppTheme.panel }
                else { Rectangle().fill(.regularMaterial) }
            }
    }

    private func offerSheet(_ listing: MarketPlayer) -> some View {
        MarketOfferSheet(listing: listing, career: store.season, balance: balance, overallDrop: store.season?.sellingClubOverallDrop(for: listing.id) ?? 0, onCancel: { selected = nil }) { amount, salary in
            if store.buyPlayer(listing.id, offer: amount, salary: salary) {
                message = "\(listing.player.name) joined your team for \(amount) credits with a weekly salary of \(salary) credits."
            }
            selected = nil
        }
    }
    private func position(_ player: Footballer) -> String { player.profile?.values["position_name"] ?? player.role }
}

private struct MarketAvatar: View {
    let name: String
    var size: CGFloat = 38
    var body: some View {
        Text(name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined())
            .font(.system(size: size * 0.31, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary).frame(width: size, height: size)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

private struct MarketPlayerRow: View {
    let listing: MarketPlayer
    let yourTeam: Bool
    let isListed: Bool
    let enabled: Bool
    let unavailableReason: String
    let onPlayer: () -> Void
    let onAction: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onPlayer) {
                HStack(spacing: 12) {
                    MarketAvatar(name: listing.player.name)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(listing.player.name).font(.body.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                        Text(listing.clubName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading).help("View \(listing.player.name)")
            Text(listing.player.profile?.values["position_name"] ?? listing.player.role)
                .font(.caption.weight(.semibold)).padding(.horizontal, 7).padding(.vertical, 5)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 5)).frame(width: 60)
            Text("\(listing.player.rating)").font(.body.weight(.medium)).monospacedDigit().frame(width: 56)
                .accessibilityLabel("Overall rating \(listing.player.rating)")
            Text(listing.player.creditsValue.formatted()).font(.body.weight(.semibold)).monospacedDigit()
                .frame(width: 80, alignment: .trailing).accessibilityLabel("\(listing.player.creditsValue) credits")
            Text("\(listing.player.currentSalary.formatted()) cr").font(.body.weight(.medium)).monospacedDigit()
                .frame(width: 100, alignment: .trailing)
                .accessibilityLabel("Weekly wage \(listing.player.currentSalary) credits")
            Button(yourTeam ? (isListed ? "Listed" : "List player") : "Make offer", action: onAction)
                .buttonStyle(.bordered).controlSize(.regular).disabled(!enabled)
                .frame(width: 100, alignment: .trailing)
                .help(enabled ? (yourTeam ? "Invite offers for this player" : "Review offer") : unavailableReason)
        }.padding(.horizontal, 18).padding(.vertical, 13)
            .background(hovered ? Color.white.opacity(0.035) : .clear)
            .onHover { hovered = $0 }
    }
}

private struct MarketOfferSheet: View {
    let listing: MarketPlayer
    let career: Season?
    let balance: Int
    let overallDrop: Double
    let onCancel: () -> Void
    let onSubmit: (Int, Int) -> Void
    @State private var offer: Int
    @State private var salary: Int

    init(listing: MarketPlayer, career: Season?, balance: Int, overallDrop: Double, onCancel: @escaping () -> Void, onSubmit: @escaping (Int, Int) -> Void) {
        self.career = career
        self.listing = listing
        self.balance = balance
        self.overallDrop = overallDrop
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        _salary = State(initialValue: listing.player.currentSalary)
        _offer = State(initialValue: listing.player.creditsValue)
    }
    private var valid: Bool { offer >= listing.player.creditsValue && offer <= balance && salary >= Footballer.minimumSalary }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Make an offer").font(.title2.weight(.semibold))
                HStack(spacing: 14) {
                    MarketAvatar(name: listing.player.name, size: 52)
                    VStack(alignment: .leading, spacing: 5) {
                        PlayerNameLink(id: listing.id, name: listing.player.name, career: career, player: listing.player, teamName: listing.clubName).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        Text("\(listing.clubName) · \(listing.player.profile?.values["position_name"] ?? listing.player.role) · \(listing.player.rating) OVR")
                            .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            VStack(spacing: 16) {
                detail("Player value", "\(listing.player.creditsValue) credits")
                detail("Available budget", "\(balance.formatted()) credits")
                Divider()
                HStack {
                    Text("Your offer").fontWeight(.medium)
                    Spacer()
                    TextField("Credits", value: $offer, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 110)
                        .accessibilityLabel("Your offer in credits")
                    Text("credits").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Weekly salary").fontWeight(.medium)
                    Spacer()
                    TextField("Credits", value: $salary, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 110)
                        .accessibilityLabel("Offered weekly player salary in credits")
                    Text("credits").foregroundStyle(.secondary)
                }
                detail("Current weekly salary", "\(listing.player.currentSalary) credits")
                Text("The full squad’s weekly wages are deducted after each home or away match.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if valid { detail("Budget if accepted", "\((balance - offer).formatted()) credits", highlighted: true) }
            }.padding(18).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12))
            if overallDrop > 2 {
                Label("Key player: the selling club’s overall would fall by \(overallDrop.formatted(.number.precision(.fractionLength(1)))) points. Each offer is reviewed with a random 5–20% premium: \((listing.player.creditsValue * 105 + 99) / 100)–\((listing.player.creditsValue * 120 + 99) / 100) credits.", systemImage: "shield.lefthalf.filled")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Label(valid ? "The selling club will review your offer." : salary < Footballer.minimumSalary ? "Offer a weekly salary of at least 10 credits." : offer < listing.player.creditsValue ? "Offer at least \(listing.player.creditsValue) credits." : "Your offer exceeds your available budget.",
                  systemImage: valid ? "info.circle" : "exclamationmark.circle")
                .font(.callout).foregroundStyle(valid ? Color.secondary : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel", role: .cancel, action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Submit offer") { onSubmit(offer, salary) }.buttonStyle(MarketCommitButtonStyle()).disabled(!valid)
            }.controlSize(.large)
        }.padding(28).frame(width: 500).background(AppTheme.background)
    }
    private func detail(_ label: String, _ value: String, highlighted: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 20)
            Text(value).fontWeight(.medium).monospacedDigit().foregroundStyle(highlighted ? AppTheme.accent : .primary)
        }.font(.callout)
    }
}

struct MarketCommitButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 18).padding(.vertical, 10)
            .foregroundStyle(isEnabled ? AppTheme.background : Color.secondary)
            .background(isEnabled ? AppTheme.accent.opacity(configuration.isPressed ? 0.75 : 1) : Color.white.opacity(0.08), in: Capsule())
            .contentShape(Capsule())
    }
}
