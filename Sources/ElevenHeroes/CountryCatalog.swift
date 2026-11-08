import Foundation

struct CatalogCountry: Decodable {
    let name: String
    let iso2: String
    let iso3: String
}
enum CountryCatalog {
    static func load() throws -> [CatalogCountry] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "countries", withExtension: "json") else {
            throw DatabaseIssue(message: "The country catalog is missing. Rebuild the app with countries.csv.")
        }
        return try JSONDecoder().decode([CatalogCountry].self, from: Data(contentsOf: url))
    }
}
