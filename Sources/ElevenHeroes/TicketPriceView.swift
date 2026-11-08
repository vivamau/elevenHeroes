import SwiftUI

struct TicketPriceEditor: View {
    @Binding var price: Int
    var body: some View {
        HStack(spacing: 12) {
            Label("Home ticket price", systemImage: "ticket")
            Spacer()
            TextField("Credits", value: $price, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder).frame(width: 70)
                .accessibilityLabel("Ticket price in credits")
            Text("credits").foregroundStyle(.secondary)
            Stepper("Ticket price", value: $price, in: 1...100).labelsHidden()
        }
    }
}

struct SeasonTicketSetupView: View {
    let year: Int
    let onStart: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State var price: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Season \(String(year))").font(.title2.weight(.semibold))
            Text("Set the ticket price for your home matches this season.").foregroundStyle(.secondary)
            TicketPriceEditor(price: $price)
            Text("Choose 1–100 credits per ticket. This price is fixed for the season.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button { onStart(price); dismiss() } label: {
                    Label("Start season", systemImage: "play.fill").padding(.horizontal, 9).padding(.vertical, 7)
                }.buttonStyle(.borderedProminent).tint(AppTheme.accent).foregroundStyle(AppTheme.background)
                    .disabled(!(1...100).contains(price))
            }
        }.padding(24).frame(width: 480).background(AppTheme.background)
    }
}
