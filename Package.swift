// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ElevenHeroes",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ElevenHeroes", targets: ["ElevenHeroes"])],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3"),
        .executableTarget(
            name: "ElevenHeroes",
            dependencies: ["CSQLite"],
            path: ".",
            exclude: ["Tests", "scripts", "README.md", "REVIEW.md", "GAMELOGIC.md", "dist", "Sources/CSQLite", "skills-lock.json", "db/player_profiles.csv", "db/team_details.csv", "db/countries.csv", "db/human_female_names.txt"],
            sources: ["Sources/ElevenHeroes"],
            resources: [
                .copy("db/db.sqlite"), .copy("db/player_profiles.json"), .copy("db/countries.json"),
                .copy("db/team_details.json"), .copy("db/human_male_names.txt"), .copy("db/halfling_surnames.txt")
            ]
        ),
        .testTarget(name: "ElevenHeroesTests", dependencies: ["ElevenHeroes"])
    ]
)
