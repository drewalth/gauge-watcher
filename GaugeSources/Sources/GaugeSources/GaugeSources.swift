import Foundation
import os

// MARK: - GaugeSources

public enum GaugeSources {

    // MARK: Public

    // MARK: Public API

    /// Loads all available gauge sources asynchronously
    public static func loadAll() async throws -> [GaugeSourceItem] {
        try await withThrowingTaskGroup(of: [GaugeSourceItem].self) { group in
            for file in GaugeSourceFile.allCases {
                group.addTask {
                    try await load(file: file)
                }
            }

            var allItems: [GaugeSourceItem] = []
            for try await items in group {
                allItems.append(contentsOf: items)
            }
            return allItems
        }
    }

    /// Loads gauges for a specific Canadian province
    public static func loadCanadianProvince(_ province: CanadianProvince) async throws -> [GaugeSourceItem] {
        let file = GaugeSourceFile.canadian(province)
        return try await load(file: file)
    }

    /// Loads gauges for USGS
    public static func loadUSGS() async throws -> [GaugeSourceItem] {
        try await load(file: .usgs)
    }

    /// Loads gauges for DWR
    public static func loadDWR() async throws -> [GaugeSourceItem] {
        try await load(file: .dwr)
    }
    
    /// Loads gauges for a specific New Zealand region
    public static func loadNZRegion(_ region: NZRegion) async throws -> [GaugeSourceItem] {
        let file = GaugeSourceFile.newZealand(region)
        return try await load(file: file)
    }
    
    /// Loads all gauges for New Zealand (all regions)
    public static func loadAllNZ() async throws -> [GaugeSourceItem] {
        try await withThrowingTaskGroup(of: [GaugeSourceItem].self) { group in
            for region in NZRegion.allCases {
                group.addTask {
                    try await loadNZRegion(region)
                }
            }
            
            var allItems: [GaugeSourceItem] = []
            for try await items in group {
                allItems.append(contentsOf: items)
            }
            return allItems
        }
    }

    // MARK: Private

    // MARK: Private Implementation

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private static let logger = Logger(
        subsystem: "com.drewalth.GaugeWatcher",
        category: "GaugeSources")

    private static func load(file: GaugeSourceFile) async throws -> [GaugeSourceItem] {
        guard let url = Bundle.module.url(forResource: file.fileName, withExtension: "json") else {
            logger.error("Failed to locate resource: \(file.fileName)")
            throw GaugeSourceError.resourceNotFound(file.fileName)
        }

        return try await Task.detached {
            let data = try Data(contentsOf: url)

            do {
                var items = try decoder.decode([GaugeSourceItem].self, from: data)
                // Assign the correct source to each item
                for index in items.indices {
                    items[index].source = file.source
                }
                return items
            } catch {
                logger.error("Failed to decode \(file.fileName): \(error.localizedDescription)")
                throw GaugeSourceError.decodingFailed(file.fileName, underlyingError: error)
            }
        }.value
    }
}

// MARK: - GaugeSourceError

public enum GaugeSourceError: LocalizedError {
    case resourceNotFound(String)
    case decodingFailed(String, underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .resourceNotFound(let resource):
            "Resource file not found: \(resource)"
        case .decodingFailed(let resource, let error):
            "Failed to decode \(resource): \(error.localizedDescription)"
        }
    }
}

// MARK: - GaugeSourceFile

enum GaugeSourceFile: CaseIterable {
    case canadian(CanadianProvince)
    case dwr
    case newZealand(NZRegion)
    case usgs

    // MARK: Internal

    static var allCases: [GaugeSourceFile] {
        [
            .canadian(.britishColumbia),
            .canadian(.ontario),
            .canadian(.quebec),
            .dwr,
            .newZealand(.wellington),
            .newZealand(.bayOfPlenty),
            .newZealand(.westCoast),
            .usgs
        ]
    }

    var fileName: String {
        switch self {
        case .canadian(let province):
            return "canada-\(province.rawValue.lowercased())"
        case .dwr:
            return "dwr-gauges"
        case .newZealand(let region):
            switch region {
            case .wellington:
                return "nz-wellington"
            case .bayOfPlenty:
                return "nz-bay-of-plenty"
            case .westCoast:
                return "nz-west-coast"
            }
        case .usgs:
            return "usgs-gages"
        }
    }

    var source: GaugeSource {
        switch self {
        case .canadian:
            return .environmentCanada
        case .dwr:
            return .dwr
        case .newZealand:
            return .lawa
        case .usgs:
            return .usgs
        }
    }
}

// MARK: - GaugeSourceItem

public struct GaugeSourceItem: Codable, Equatable, Identifiable, Sendable {

    // MARK: Lifecycle

    public init(
        id: String,
        name: String,
        latitude: Float,
        longitude: Float,
        siteID: String,
        state: String,
        country: String,
        source: GaugeSource,
        zone: String? = nil,
        metric: GaugeSourceMetric) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.siteID = siteID
        self.state = state
        self.country = country
        self.zone = zone
        self.metric = metric
        self.source = source
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Float.self, forKey: .latitude)
        longitude = try container.decode(Float.self, forKey: .longitude)
        state = try container.decode(String.self, forKey: .state)
        
        // Handle both string and integer IDs
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }

        let country = try container.decode(String.self, forKey: .country)
        let defaultMetric = country == "CA" ? GaugeSourceMetric.cms : GaugeSourceMetric.cfs
        self.country = country
        metric = try container.decodeIfPresent(GaugeSourceMetric.self, forKey: .metric) ?? defaultMetric
        siteID = try container.decode(String.self, forKey: .siteID)
        zone = try container.decodeIfPresent(String.self, forKey: .zone)

        // Source is assigned after decoding
        source = nil
    }

    // MARK: Public

    public var id: String
    public var name: String
    public var latitude: Float
    public var longitude: Float
    public var siteID: String
    public var state: String
    public var country: String
    public var metric: GaugeSourceMetric
    public var zone: String?
    public internal(set) var source: GaugeSource?

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, state, id, metric, country, zone
        case siteID = "siteId"
    }
}

// MARK: - GaugeSource

public enum GaugeSource: String, Codable, CaseIterable, Sendable {
    case usgs = "USGS"
    case environmentCanada = "ENVIRONMENT_CANADA"
    case lawa = "LAWA"
    case dwr = "DWR"
}

// MARK: - CanadianProvince

public enum CanadianProvince: String, CaseIterable, Sendable {
    case britishColumbia = "BC"
    case quebec = "QC"
    case ontario = "ON"
    case alberta = "AB"
}

// MARK: - NZRegion

public enum NZRegion: String, CaseIterable, Codable, Sendable {
    case wellington = "Wellington"
    case bayOfPlenty = "Bay of Plenty"
    case westCoast = "West Coast"

    public var zones: [NZZone] {
        switch self {
        case .wellington:
            [.ruamaahanga, .wellingtonHarbourAndHuttValley, .teAwaruaOPorirua]
        case .bayOfPlenty:
            [.kaituna]
        case .westCoast:
            [.buller, .grey, .hokitika]
        }
    }
}

// MARK: - NZZone

public enum NZZone: String, CaseIterable, Codable, Sendable {
    // wellington
    case ruamaahanga = "Ruamahanga"
    case wellingtonHarbourAndHuttValley = "Wellington Harbour and Hutt Valley"
    case teAwaruaOPorirua = "Te Awarua o Porirua"

    // bay of plenty
    case kaituna = "Kaituna-Maketu-Pongakawa"

    // west coast
    case buller = "Buller"
    case grey = "Grey"
    case hokitika = "Hokitika"
}

// MARK: - GaugeSourceMetric

public enum GaugeSourceMetric: String, CaseIterable, Codable, Sendable {
    /// Cubic Meters per Second
    case cms = "CMS"
    /// Cubic Feet per Second
    case cfs = "CFS"
    /// Feet stage height
    case feetHeight = "FT"
    /// Meters stage height
    case meterHeight = "M"
}
