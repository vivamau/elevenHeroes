import SwiftUI

struct StadiumView: View {
    @Bindable var store: GameStore
    @State private var seatsText = "1000"
    @State private var message: String?

    private var season: Season? { store.season }
    private var club: Club? {
        guard let season else { return nil }
        return season.clubs.first { $0.id == season.selectedClub }
    }
    private var seats: Int? { Int(seatsText.trimmingCharacters(in: .whitespaces)) }
    private var cost: Int? {
        guard let seats, seats > 0, let season else { return nil }
        return season.homeTicketPrice * seats * 100
    }

    var body: some View {
        if let season, let club {
            VStack(spacing: 22) {
                card("Stadium") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(club.stadiumName ?? "Stadium").font(.headline).foregroundStyle(AppTheme.accent)
                        LabeledContent("Current capacity") {
                            Text("\(club.stadiumCapacity ?? 0) seats").monospacedDigit()
                        }
                        LabeledContent("Ticket price") {
                            Text("\(season.homeTicketPrice) credits").monospacedDigit()
                        }
                        LabeledContent("Credit balance") {
                            Text("\(season.credits.formatted()) credits").monospacedDigit()
                        }
                        Divider()
                        HStack {
                            Text("New seats")
                            Spacer()
                            TextField("Seats", text: $seatsText)
                                .textFieldStyle(.roundedBorder).frame(width: 120)
                                .accessibilityLabel("Number of new seats")
                        }
                        if let cost {
                            Text("Cost: \(cost.formatted()) credits").font(.callout.weight(.semibold))
                        }
                        if let message {
                            Text(message).font(.caption).foregroundStyle(.orange)
                        }
                        Button("Improve stadium") {
                            improve()
                        }.buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background)
                            .disabled(cost == nil || (cost ?? 0) > season.credits)
                    }
                }
                card("How it works") {
                    Text("Each new seat costs your current ticket price × 100 credits. The expanded capacity applies to future home matches.")
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            ContentUnavailableView("No career", systemImage: "sportscourt", description: Text("Start a career to manage your stadium."))
        }
    }

    private func improve() {
        guard let season = store.season else { return }
        guard let seats, seats > 0 else { message = "Enter a positive number of seats."; return }
        guard let clubIndex = season.clubs.firstIndex(where: { $0.id == season.selectedClub }) else { return }
        let total = season.homeTicketPrice * seats * 100
        guard total <= season.credits else { message = "Not enough credits."; return }
        store.season?.clubs[clubIndex].stadiumCapacity = (store.season?.clubs[clubIndex].stadiumCapacity ?? 0) + seats
        store.season?.creditBalance = season.credits - total
        store.save()
        message = "Added \(seats) seats."
        seatsText = "1000"
    }
}

private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 20) {
        Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.7).foregroundStyle(.secondary)
        content()
    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
}