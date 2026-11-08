import SwiftUI

struct IncomingOffersView: View {
    @Bindable var store: GameStore
    let onPlayer: (MarketPlayer) -> Void
    let onComplete: (String) -> Void
    @State private var reviewing: TransferOffer?

    private var offers: [TransferOffer] { store.season?.pendingOffers ?? [] }
    private func player(for offer: TransferOffer) -> Footballer? {
        store.season?.clubs.first { $0.id == store.season?.selectedClub }?.players.first { $0.id == offer.playerID }
    }
    private func clubName(_ id: Int) -> String { store.season?.clubs.first { $0.id == id }?.name ?? "Unknown club" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "tray").foregroundStyle(AppTheme.accent)
                Text("Offers from your league").font(.headline)
                Spacer()
                Text("Matchweek \(store.season?.round ?? 1)").font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Clubs send new bids after each matchweek. Listed players are prioritised for bids.")
                .font(.callout).foregroundStyle(.secondary)
            if (store.season?.squadCount ?? 0) <= 16 {
                Label("You need more than 16 players to accept a sale. You can still review or reject offers.", systemImage: "lock")
                    .font(.callout).foregroundStyle(.orange)
            }
            if offers.isEmpty {
                ContentUnavailableView("No pending offers", systemImage: "tray", description: Text("Play the next matchweek to hear from other clubs."))
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(offers) { offer in
                            if let player = player(for: offer) { offerRow(offer, player: player) }
                        }
                    }
                }.frame(maxHeight: 430)
            }
        }
        .sheet(item: $reviewing) { offer in
            if let player = player(for: offer) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Accept transfer offer?").font(.title2.weight(.semibold))
                    VStack(alignment: .leading, spacing: 6) {
                        PlayerNameLink(id: player.id, name: player.name, career: store.season).font(.title3.weight(.semibold))
                        Text("To \(clubName(offer.buyerClubID))").foregroundStyle(.secondary)
                    }
                    VStack(spacing: 14) {
                        detail("Offer", "\(offer.credits) credits")
                        detail("Player value", "\(player.creditsValue) credits")
                        Divider()
                        detail("Budget after sale", "\(((store.season?.credits ?? 0) + offer.credits).formatted()) credits")
                        detail("Squad after sale", "\(max(0, (store.season?.squadCount ?? 0) - 1)) players")
                    }.padding(18).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                    if player.role == "GK" && (store.season?.goalkeeperCount ?? 0) <= 2 {
                        Label("Keep at least two goalkeepers. Buy another before accepting this offer.", systemImage: "lock").font(.callout).foregroundStyle(.orange)
                    }
                    Text("The player will move immediately. If they are in your starting XI, a replacement will be selected from your squad.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Cancel", role: .cancel) { reviewing = nil }.keyboardShortcut(.cancelAction)
                        Spacer()
                        Button("Accept \(offer.credits) credits") {
                            if store.acceptOffer(offer.id) {
                                onComplete("\(player.name) joined \(clubName(offer.buyerClubID)) for \(offer.credits) credits.")
                            }
                            reviewing = nil
                        }.buttonStyle(MarketCommitButtonStyle()).disabled(!(store.season?.canSellPlayer(player.id) ?? false))
                    }
                }.padding(28).frame(width: 500).background(AppTheme.background)
            } else {
                VStack(spacing: 20) {
                    Text("This offer is no longer available.")
                    Button("Close") { reviewing = nil }
                }.padding(28)
            }
        }
    }

    private func offerRow(_ offer: TransferOffer, player: Footballer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Button(player.name) {
                        onPlayer(MarketPlayer(player: player, clubID: store.season?.selectedClub, clubName: clubName(store.season?.selectedClub ?? 0)))
                    }.buttonStyle(.plain).font(.headline)
                    Label(clubName(offer.buyerClubID), systemImage: "shield.lefthalf.filled")
                        .font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 5) {
                    Text("\(offer.credits) credits").font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(AppTheme.accent)
                    Text(offer.credits == player.creditsValue ? "Matches player value" : "\(offer.credits - player.creditsValue) above value")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Received in matchweek \(offer.matchweek)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Reject") {
                    if store.rejectOffer(offer.id) { onComplete("Offer from \(clubName(offer.buyerClubID)) for \(player.name) rejected.") }
                }.buttonStyle(.bordered).accessibilityLabel("Reject offer for \(player.name)")
                Button("Review offer") { reviewing = offer }.buttonStyle(.bordered)
                    .accessibilityLabel("Review offer for \(player.name)")
            }
        }.padding(18).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
    }
    private func detail(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).monospacedDigit()
        }.font(.callout)
    }
}
