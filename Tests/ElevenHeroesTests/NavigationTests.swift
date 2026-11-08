import Foundation
import Testing
@testable import ElevenHeroes

struct NavigationTests {
    @Test @MainActor func databaseNavigationPreservesCareerAndRefreshesClubs() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = GameStore(saveURL: folder.appending(path: "season.json"))
        store.generateCareerData()
        store.start(1)
        store.play()
        let saved = try Data(contentsOf: store.saveURL)
        let round = store.season?.round
        let lineup = store.season?.lineup
        store.openDatabaseManager()
        #expect(store.managingDatabase)
        _ = try FootballDatabase(url: store.databaseURL, writable: true).generate(.team, count: 2)
        store.returnToMainPage()
        #expect(!store.managingDatabase)
        #expect(store.screen == "Overview")
        #expect(store.databaseClubs.count == 2)
        #expect(store.season?.round == round)
        #expect(store.season?.lineup == lineup)
        #expect(try Data(contentsOf: store.saveURL) == saved)
        store.openDatabaseManager()
        #expect(store.managingDatabase)
        store.returnToMainPage()
        #expect(!store.managingDatabase)
    }
}
