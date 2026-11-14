import Foundation

/// Narrative detail only: choosing a description never consumes simulation randomness.
enum GoalCommentary {
    static func describe(scorer: String, assist: String?, variation: Int) -> String {
        let descriptions: [String]
        if let assist {
            descriptions = [
                "\(assist) delivers a cross into the box and \(scorer) heads it into the corner.",
                "\(assist) slips a pass through the defence. \(scorer) races clear and slots it past the keeper.",
                "\(assist) pulls the ball back from the byline and \(scorer) sweeps it home first time.",
                "\(scorer) meets \(assist)’s lofted pass with a volley that flies into the net.",
                "A quick exchange opens up the defence. \(assist) finds \(scorer), who finishes low into the corner.",
                "\(assist) squares the ball across the six-yard box, leaving \(scorer) a close-range tap-in."
            ]
        } else {
            descriptions = [
                "\(scorer) dribbles past a defender and drives a low shot beyond the keeper.",
                "\(scorer) pounces on a loose ball in the box and fires it into the net.",
                "\(scorer) finds space outside the box and curls a shot into the top corner.",
                "The keeper can only parry the ball, and \(scorer) reacts first to bury the rebound.",
                "\(scorer) intercepts a loose defensive pass, rounds the keeper and rolls the ball home.",
                "\(scorer) turns away from a defender inside the box and strikes into the far corner."
            ]
        }
        let index = ((variation % descriptions.count) + descriptions.count) % descriptions.count
        return descriptions[index]
    }
}
