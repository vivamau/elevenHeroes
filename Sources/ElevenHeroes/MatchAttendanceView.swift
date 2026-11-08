import SwiftUI

struct MatchAttendanceView: View {
    let fixture: Fixture
    var showRevenue = true
    var body: some View {
        if fixture.homeGoals != nil {
            HStack(spacing: 8) {
                Label(fixture.attendance.map { "\($0.formatted()) spectators" } ?? "Attendance not recorded", systemImage: "person.3")
                if showRevenue, let revenue = fixture.ticketRevenue { Text("· \(revenue.formatted()) credits earned by home team") }
                if let name = fixture.stadiumName { Text("· \(name)") }
                if let capacity = fixture.stadiumCapacity { Text("· \(capacity.formatted()) capacity") }
            }.font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
