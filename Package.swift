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
            exclude: ["Tests", "scripts", "README.md", "REVIEW.md", "dist", "Sources/CSQLite", "skills-lock.json", "db/player_profiles.csv", "db/team_details.csv", "db/countries.csv"],
            sources: ["Sources/ElevenHeroes"],
            resources: [.copy("db/db.sqlite"), .copy("db/player_profiles.json"), .copy("db/countries.json"), .copy("db/team_details.json")]
        ),
        .testTarget(name: "ElevenHeroesTests", dependencies: ["ElevenHeroes"])
    ]
)
