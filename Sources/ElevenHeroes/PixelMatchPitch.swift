import SwiftUI

/// Presentation-only positions on a 228 × 80 pixel pitch. No simulation randomness is consumed.
enum PixelMatchMotion {
    struct Player {
        let team: Int
        let number: Int
        let x: Double
        let y: Double
    }

    static func players(at time: Double) -> [Player] {
        let formation: [(Double, Double)] = [
            (15, 40), (48, 15), (43, 32), (43, 49), (48, 65),
            (83, 14), (77, 32), (77, 49), (83, 66), (111, 28), (111, 53)
        ]
        return (0..<2).flatMap { team in
            formation.enumerated().map { index, point in
                let phase = time * 0.8 + Double(index) * 1.7 + Double(team) * 2.4
                let keeper = index == 0
                let shift = sin(time * 0.45) * (keeper ? 1 : 10)
                let x = point.0 + sin(phase) * (keeper ? 1 : 6) + shift
                let y = point.1 + cos(phase * 0.7) * (keeper ? 5 : 4)
                return Player(team: team, number: index + 1, x: team == 0 ? x : 228 - x, y: y)
            }
        }
    }

    static func ball(at time: Double) -> CGPoint {
        let players = players(at: time)
        // A repeating sequence of passes alternates possession between the teams.
        let sequence = [9, 6, 5, 8, 10, 14, 17, 19, 20, 16, 13, 7]
        let step = Int(time / 1.4)
        let from = players[sequence[step % sequence.count]]
        let to = players[sequence[(step + 1) % sequence.count]]
        let progress = min(1, (time / 1.4 - Double(step)) * 1.5)
        return CGPoint(x: from.x + (to.x - from.x) * progress + 2,
                       y: from.y + (to.y - from.y) * progress + 3)
    }
}

struct PixelMatchPitch: View {
    let elapsed: Double
    let reduceMotion: Bool
    var homeKit = "#C2F559"
    var awayKit = "#00BCD4"

    var body: some View {
        Canvas { context, size in
            let unit = max(1, floor(min(size.width / 228, size.height / 80)))
            let origin = CGPoint(x: (size.width - 228 * unit) / 2, y: (size.height - 80 * unit) / 2)
            func block(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ color: Color) {
                let rect = CGRect(x: origin.x + floor(x) * unit, y: origin.y + floor(y) * unit,
                                  width: width * unit, height: height * unit)
                context.fill(Path(rect), with: .color(color))
            }
            func outline(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
                block(x, y, width, 1, .white.opacity(0.65))
                block(x, y + height - 1, width, 1, .white.opacity(0.65))
                block(x, y, 1, height, .white.opacity(0.65))
                block(x + width - 1, y, 1, height, .white.opacity(0.65))
            }
            block(0, 0, 228, 80, Color(red: 0.06, green: 0.25, blue: 0.16))
            for x in stride(from: 4, to: 224, by: 20) { block(Double(x), 4, 10, 72, .white.opacity(0.035)) }
            outline(5, 5, 218, 70)
            block(114, 5, 1, 70, .white.opacity(0.65))
            outline(5, 22, 28, 36); outline(195, 22, 28, 36)
            outline(5, 30, 11, 20); outline(212, 30, 11, 20)
            outline(1, 33, 5, 14); outline(222, 33, 5, 14)
            // Stepped centre circle, drawn with square pixels.
            for degree in stride(from: 0, to: 360, by: 6) {
                let angle = Double(degree) * .pi / 180
                block(114 + cos(angle) * 13, 40 + sin(angle) * 13, 1, 1, .white.opacity(0.65))
            }
            block(114, 40, 1, 1, .white)
            let time = reduceMotion ? 0 : elapsed
            for player in PixelMatchMotion.players(at: time).sorted(by: { $0.y < $1.y }) {
                let kit: Color = player.number == 1 ? TeamKits.goalkeeper(home: homeKit, away: awayKit)
                    : TeamKits.color(player.team == 0 ? homeKit : awayKit)
                let stride = reduceMotion ? 0 : Int(time * 5 + Double(player.number)) % 2
                block(player.x - 2, player.y + 4, 6, 1, .black.opacity(0.25))
                block(player.x, player.y - 4, 2, 2, Color(red: 0.88, green: 0.64, blue: 0.42))
                block(player.x - 1, player.y - 2, 4, 4, kit)
                block(player.x - 2, player.y - 1 + Double(stride), 1, 2, kit)
                block(player.x + 3, player.y - Double(stride), 1, 2, kit)
                block(player.x - 1, player.y + 2, 4, 1, .black)
                block(player.x - 1, player.y + 3, 1, Double(1 + stride), .white)
                block(player.x + 2, player.y + 3, 1, Double(2 - stride), .white)
            }
            let ball = PixelMatchMotion.ball(at: time)
            block(ball.x, ball.y, 2, 2, .white)
            block(ball.x, ball.y, 1, 1, .black)
        }
        .accessibilityLabel("Football pitch with eleven players per team. Team shirts match the colour legend, with a moving ball.")
    }
}
