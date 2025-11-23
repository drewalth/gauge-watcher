import Foundation
import os

// MARK: - GaugeSources

public struct GaugeSources {

    // MARK: Lifecycle

    public init() { }

    // MARK: Public

    public static func load() throws -> [GaugeSourceItem] {
        let resources = ["usgs-gages", "canada-bc", "canada-on", "canada-qc", "dwr-gauges"]
        var results: [GaugeSourceItem] = []

        for resource in resources {
            guard let url = Bundle.module.url(forResource: resource, withExtension: "json") else { throw Errors.invalidJSONURL }
            let data = try Data(contentsOf: url)

            let decoder = JSONDecoder()
            // add `source` val based on the resource name
            let gages = try decoder.decode([GaugeSourceItem].self, from: data).map {
                var item = $0
                item.source = {
                    switch resource {
                    case "usgs-gages":
                        return .usgs
                    case "canada-bc":
                        return .environmentCanada
                    case "canada-on":
                        return .environmentCanada
                    case "canada-qc":
                        return .environmentCanada
                    case "dwr-gauges":
                        return .dwr
                    default:
                        return nil
                    }
                }()
                return item
            }
            results.append(contentsOf: gages)
        }
        return results
    }

    //    public func load(source: GaugeSource, province: CanadianProvince? = nil) throws -> [GaugeSourceItem] {
    //        if source == .usgs, province != nil { throw Errors.invalidOptionsProvided }
    //        if source == .environmentCanada, province == nil { throw Errors.invalidOptionsProvided }
    //
    //        let resource: String = {
    //            if source == .usgs {
    //                return "usgs-gages"
    //            }
    //
    //            if source == .lawa {
    //                return "nz-gauges"
    //            }
    //
    //            if source == .dwr {
    //                return "dwr-gauges"
    //            }
    //
    //            switch province {
    //            case .britishColumbia:
    //                return "canada-bc"
    //            case .quebec:
    //                return "canada-qc"
    //            case .ontario:
    //                return "canada-on"
    //            default:
    //                return "canada-bc"
    //            }
    //        }()
    //
    //        guard let url = Bundle.module.url(forResource: resource, withExtension: "json") else { throw Errors.invalidJSONURL }
    //        let data = try Data(contentsOf: url)
    //
    //        let decoder = JSONDecoder()
    //        do {
    //            return try decoder.decode([GaugeSourceItem].self, from: data)
    //        } catch {
    //            logger.error("Failed to decode source data for: \(resource)")
    //            logger.error("Error: \(error)")
    //            throw Errors.failedToDecode
    //        }
    //    }

    // MARK: Internal

    enum Errors: Error, LocalizedError {
        case invalidOptionsProvided, invalidJSONURL, failedToDecode

        public var errorDescription: String? {
            switch self {
            case .failedToDecode:
                "Failed to Decode source data"
            case .invalidJSONURL:
                "Bad URL"
            case .invalidOptionsProvided:
                "Invalid Options Provided"
            }
        }
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.drewalth.GaugeWatcher", category: "GageSources")

}

// MARK: - GaugeSourceItem

public struct GaugeSourceItem: Codable, Equatable, Identifiable {

    // MARK: Lifecycle

    public init(
        id: String,
        name: String,
        latitude: Float,
        longitude: Float,
        siteID: String,
        state: String,
        country: String,
        source: GaugeSource?,
        zone: String?,
        metric: String) {
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
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString

        let country = try container.decode(String.self, forKey: .country)
        let defaultMetric = country == "CA" ? "CMS" : "CFS"
        self.country = country
        metric = try container.decodeIfPresent(String.self, forKey: .metric) ?? defaultMetric
        siteID = try container.decode(String.self, forKey: .siteID)

        zone = try container.decodeIfPresent(String.self, forKey: .zone)
    }

    // MARK: Public

    public var id: String
    public var name: String
    public var latitude: Float
    public var longitude: Float
    public var siteID: String
    public var state: String
    public var country: String
    public var metric: String
    public var zone: String?
    public var source: GaugeSource?

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, state, id, metric, country, zone
        case siteID = "siteId"
    }

    let uuid = UUID()
}

// MARK: - GaugeSource

public enum GaugeSource: String, Codable, CaseIterable, Sendable {
    case usgs = "USGS"
    case environmentCanada = "ENVIRONMENT_CANADA"
    case lawa = "LAWA"
    case dwr = "DWR"
}

// MARK: - CanadianProvince

public enum CanadianProvince: String {
    case britishColumbia = "BC"
    case quebec = "QC"
    case ontario = "ON"
    case alberta = "AB"
}

// MARK: - NZRegion

public enum NZRegion: String, CaseIterable, Codable {
    case wellington = "Wellington"
    case bayOfPlenty = "Bay of Plenty"
    case westCoast = "West Coast"

    var zones: [NZZone] {
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

public enum NZZone: String, CaseIterable, Codable {
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
