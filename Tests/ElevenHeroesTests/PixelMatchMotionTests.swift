import Testing
@testable import ElevenHeroes

struct PixelMatchMotionTests {
    @Test func bothTeamsStayOnPitchThroughoutPlayback() {
        for tick in 0...600 {
            let time = Double(tick) / 10
            let players = PixelMatchMotion.players(at: time)
            #expect(players.count == 22)
            for team in 0..<2 {
                #expect(players.filter { $0.team == team }.count == 11)
                #expect(players.filter { $0.team == team && $0.number == 1 }.count == 1)
            }
            #expect(players.allSatisfy { (7...220).contains($0.x) && (9...71).contains($0.y) })
            let ball = PixelMatchMotion.ball(at: time)
            #expect((5...223).contains(ball.x) && (5...75).contains(ball.y))
        }
    }

    @Test func everyPlayerMovesAndGoalkeepersStayNearTheirGoals() {
        let start = PixelMatchMotion.players(at: 0)
        let later = PixelMatchMotion.players(at: 3)
        for index in start.indices {
            #expect(start[index].x != later[index].x || start[index].y != later[index].y)
        }
        for time in 0...60 {
            let players = PixelMatchMotion.players(at: Double(time))
            #expect(players[0].x < 20)
            #expect(players[11].x > 208)
        }
    }
}
