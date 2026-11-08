import Foundation

struct PlayerAttribute: Identifiable {
    let id: String
    let label: String
    var range: ClosedRange<Int> = 1...20
    var initial: Int = 10
}
struct AttributeChoice: Identifiable {
    let id: String
    let name: String
}
enum PlayerAttributes {
    static let physical: [PlayerAttribute] = [
        .init(id: "player_skills_phys_acceleration", label: "Acceleration"),
        .init(id: "player_skills_phys_agility", label: "Agility"),
        .init(id: "player_skills_phys_balance", label: "Balance"),
        .init(id: "player_skills_phys_jumping", label: "Jumping"),
        .init(id: "player_skills_phys_pace", label: "Pace"),
        .init(id: "player_skills_phys_stamina", label: "Stamina"),
        .init(id: "player_skills_phys_strength", label: "Strength"),
        .init(id: "player_skills_phys_condition", label: "Condition", range: 0...100, initial: 100)
    ]
    static let mental: [PlayerAttribute] = [
        .init(id: "p_skills_mental_aggression", label: "Aggression"),
        .init(id: "p_skills_mental_anticipation", label: "Anticipation"),
        .init(id: "p_skills_mental_bravery", label: "Bravery"),
        .init(id: "p_skills_mental_creativity", label: "Creativity"),
        .init(id: "p_skill_mental_decisions", label: "Decisions"),
        .init(id: "p_skill_mental_determination", label: "Determination"),
        .init(id: "p_skill_mental_flair", label: "Flair"),
        .init(id: "p_skill_mental_influence", label: "Influence"),
        .init(id: "p_skill_mental_off_the_ball", label: "Off the ball"),
        .init(id: "p_skill_mental_positioning", label: "Positioning"),
        .init(id: "p_skill_mental_teamwork", label: "Teamwork"),
        .init(id: "p_skill_mental_work_rate", label: "Work rate")
    ]
    static var defaults: [String: String] {
        var values = Dictionary(uniqueKeysWithValues: (physical + mental).map { ($0.id, String($0.initial)) })
        values["player_foot_id"] = ""
        values["player_morale_id"] = ""
        return values
    }
    static func randomized(choices: [String: [AttributeChoice]]) throws -> [String: String] {
        var values = defaults
        for attribute in physical + mental {
            values[attribute.id] = String(Int.random(in: attribute.id == "player_skills_phys_condition" ? 75...100 : 8...18))
        }
        for key in ["player_foot_id", "player_morale_id"] {
            guard let choice = choices[key]?.randomElement() else {
                throw DatabaseIssue(message: "The \(key == "player_foot_id" ? "player_foot" : "player_morale") table has no options. Populate it before creating players.")
            }
            values[key] = choice.id
        }
        return values
    }
    static func validation(_ values: [String: String]) -> String? {
        for attribute in physical + mental {
            guard let number = Int(values[attribute.id] ?? ""), attribute.range.contains(number) else {
                return "\(attribute.label) must be between \(attribute.range.lowerBound) and \(attribute.range.upperBound)."
            }
        }
        if values["player_foot_id", default: ""].isEmpty { return "Choose a preferred foot." }
        if values["player_morale_id", default: ""].isEmpty { return "Choose morale." }
        return nil
    }
}
