import SwiftUI

/// A tactical presentation of the existing illustrative playback, independent of match results.
struct TacticalMatchPitch: View {
    let elapsed: Double
    let reduceMotion: Bool
    let homeKit: String
    let awayKit: String

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(x: 12, y: 10, width: max(1, size.width - 24), height: max(1, size.height - 20))
            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            }
            func box(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CGRect {
                CGRect(origin: point(x, y), size: CGSize(width: width * rect.width, height: height * rect.height))
            }
            let line = Color.white.opacity(0.55)
            context.fill(Path(rect), with: .color(Color(red: 0.035, green: 0.33, blue: 0.24)))
            for index in 0..<12 where index.isMultiple(of: 2) {
                context.fill(Path(box(Double(index) / 12, 0, 1.0 / 12, 1)), with: .color(.white.opacity(0.035)))
            }
            context.stroke(Path(rect), with: .color(line), lineWidth: 1.5)
            var halfway = Path()
            halfway.move(to: point(0.5, 0)); halfway.addLine(to: point(0.5, 1))
            context.stroke(halfway, with: .color(line), lineWidth: 1)
            let radius = rect.height * 0.15
            let centre = point(0.5, 0.5)
            context.stroke(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)), with: .color(line), lineWidth: 1)
            for x in [0.0, 0.84] {
                context.stroke(Path(box(x, 0.21, 0.16, 0.58)), with: .color(line), lineWidth: 1)
            }
            for x in [0.0, 0.94] {
                context.stroke(Path(box(x, 0.36, 0.06, 0.28)), with: .color(line), lineWidth: 1)
            }
            for x in [-0.015, 1.0] {
                context.stroke(Path(box(x, 0.43, 0.015, 0.14)), with: .color(.white), lineWidth: 2)
            }
            let time = reduceMotion ? 0 : elapsed
            for player in PixelMatchMotion.players(at: time) {
                let location = point(player.x / 228, player.y / 80)
                let marker = CGRect(x: location.x - 8, y: location.y - 8, width: 16, height: 16)
                let kit = player.number == 1 ? TeamKits.goalkeeper(home: homeKit, away: awayKit)
                    : TeamKits.color(player.team == 0 ? homeKit : awayKit)
                context.fill(Path(ellipseIn: marker.offsetBy(dx: 0, dy: 2)), with: .color(.black.opacity(0.35)))
                context.fill(Path(ellipseIn: marker), with: .color(kit))
                context.stroke(Path(ellipseIn: marker), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                context.draw(Text("\(player.number)").font(.system(size: 8, weight: .heavy)).foregroundStyle(.black), at: location)
            }
            let ball = PixelMatchMotion.ball(at: time)
            let position = point(ball.x / 228, ball.y / 80)
            context.draw(Text(Image(systemName: "soccerball")).font(.system(size: 12)).foregroundStyle(.white), at: position)
        }
        .accessibilityLabel("Illustrative tactical pitch. Eleven numbered markers per team, with a moving ball.")
    }
}
