import SharedFeatures
import FoundationModels
import Foundation

public protocol GaugeBotProtocol: Sendable {
    func query(text: String) async throws -> String
}

#if os(macOS)


// MARK: - LoadGaugesTool Arguments
//
///// Arguments for the LoadGaugesTool, describing query filters
//@Generable
//struct LoadGaugesArguments: Codable, Sendable {
//    /// Optional name filter - searches gauge names containing this text
//    @Guide(description: "Filter gauges by name (partial match)")
//    var name: String?
//    
//    /// Country code filter (e.g., "US", "CA")
//    @Guide(description: "Filter by country code, defaults to US")
//    var country: String?
//    
//    /// State/province code filter (e.g., "CO", "AK")
//    @Guide(description: "Filter by state or province code")
//    var state: String?
//    
//    /// Whether to only return favorite gauges
//    @Guide(description: "If true, only return favorited gauges")
//    var favoritesOnly: Bool?
//}
//
//// MARK: - LoadGaugesTool Output
//
///// Simplified gauge data for LLM output
//struct GaugeResult: Codable, Sendable, PromptRepresentable {
//    var promptRepresentation: Prompt
//    
//    let id: Int
//    let name: String
//    let siteID: String
//    let country: String
//    let state: String
//    let latitude: Double
//    let longitude: Double
//
//    public var promptValue: String {
//        "\(name) [ID: \(siteID)] — \(country), \(state) (lat: \(latitude), lon: \(longitude))"
//    }
//}
//
//// MARK: - LoadGaugesTool
//
//struct LoadGaugesTool: Tool {
//    typealias Arguments = LoadGaugesArguments
//    typealias Output = [GaugeResult]
//    
//    let name = "loadGauges"
//    let description = "Search and load water gauges from the database. Use filters to narrow results by location or name."
//
//    @Dependency(\.gaugeService) var gaugeService: GaugeService
//
//    func call(arguments: LoadGaugesArguments) async throws -> [GaugeResult] {
//        let options = GaugeQueryOptions(
//            name: arguments.name,
//            country: arguments.country,
//            state: arguments.state,
//            favorite: arguments.favoritesOnly
//        )
//        
//        let gauges = try await gaugeService.loadGauges(options)
//        
//        return gauges.map { gauge in
//            GaugeResult(
//                id: gauge.id,
//                name: gauge.name,
//                siteID: gauge.siteID,
//                country: gauge.country,
//                state: gauge.state,
//                latitude: gauge.latitude,
//                longitude: gauge.longitude
//            )
//        }
//    }
//}

// TODO: this tool compiles. the one that is commented out does not. move the concept of commented out tool here.
struct LoadGaugesTool: Tool {
    let name = "searchBreadDatabase"
    let description = "Searches a local database for bread recipes."


    @Generable
    struct Arguments {
        @Guide(description: "The type of bread to search for")
        var searchTerm: String
        @Guide(description: "The number of recipes to get", .range(1...6))
        var limit: Int
    }


    struct Recipe {
        var name: String
        var description: String
        var link: URL
    }
    
    func call(arguments: Arguments) async throws -> [String] {
        var recipes: [Recipe] = []
        
        // Put your code here to retrieve a list of recipes from your database.
        
        let formattedRecipes = recipes.map {
            "Recipe for '\($0.name)': \($0.description) Link: \($0.link)"
        }
        return formattedRecipes
    }
}

// MARK: - GaugeBot

public struct GaugeBot: GaugeBotProtocol {
    public init() {}
    
    public func query(text: String) async throws -> String {
        let model = SystemLanguageModel.default
        let session = LanguageModelSession(model: model, tools: [LoadGaugesTool()])

        let response = try await session.respond(to: text)
        return response.content
    }
}

#else

public struct GaugeBot: GaugeBotProtocol {
    public init() {}
    
    public func query(text: String) async throws -> String {
        "GaugeBot is not available on this platform"
    }
}

#endif


