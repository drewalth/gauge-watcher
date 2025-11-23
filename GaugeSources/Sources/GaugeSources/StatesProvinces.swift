//
//  StatesProvinces.swift
//  GaugeSources
//
//  Created by Andrew Althage on 11/23/25.
//

import Foundation

// MARK: - StatesProvinces

public enum StatesProvinces {

    public enum USState: String, CaseIterable, Hashable, Sendable {
        case alabama = "AL"
        case alaska = "AK"
        case arizona = "AZ"
        case arkansas = "AR"
        case california = "CA"
        case colorado = "CO"
        case connecticut = "CT"
        case delaware = "DE"
        case districtOfColumbia = "DC"
        case florida = "FL"
        case georgia = "GA"
        case hawaii = "HI"
        case idaho = "ID"
        case illinois = "IL"
        case indiana = "IN"
        case iowa = "IA"
        case kansas = "KS"
        case louisiana = "LA"
        case maine = "ME"
        case maryland = "MD"
        case massachusetts = "MA"
        case michigan = "MI"
        case minnesota = "MN"
        case mississippi = "MS"
        case missouri = "MO"
        case montana = "MT"
        case nebraska = "NE"
        case nevada = "NV"
        case newHampshire = "NH"
        case newJersey = "NJ"
        case newMexico = "NM"
        case newYork = "NY"
        case northCarolina = "NC"
        case ohio = "OH"
        case oklahoma = "OK"
        case oregon = "OR"
        case pennsylvania = "PA"
        case rhodeIsland = "RI"
        case southCarolina = "SC"
        case southDakota = "SD"
        case tennessee = "TN"
        case texas = "TX"
        case utah = "UT"
        case vermont = "VT"
        case virginia = "VA"
        case washington = "WA"
        case westVirginia = "WV"
        case wisconsin = "WI"
        case wyoming = "WY"

        // MARK: Public

        public var value: StateValue {
            StateValue(name: name, abbreviation: rawValue)
        }

        public var name: String {
            switch self {
            case .alaska: return "Alaska"
            case .alabama: return "Alabama"
            case .arkansas: return "Arkansas"
            case .arizona: return "Arizona"
            case .california: return "California"
            case .colorado: return "Colorado"
            case .connecticut: return "Connecticut"
            case .districtOfColumbia: return "District of Columbia"
            case .delaware: return "Delaware"
            case .florida: return "Florida"
            case .georgia: return "Georgia"
            case .hawaii: return "Hawaii"
            case .iowa: return "Iowa"
            case .idaho: return "Idaho"
            case .illinois: return "Illinois"
            case .indiana: return "Indiana"
            case .kansas: return "Kansas"
            case .louisiana: return "Louisiana"
            case .massachusetts: return "Massachusetts"
            case .maryland: return "Maryland"
            case .maine: return "Maine"
            case .michigan: return "Michigan"
            case .minnesota: return "Minnesota"
            case .missouri: return "Missouri"
            case .mississippi: return "Mississippi"
            case .montana: return "Montana"
            case .northCarolina: return "North Carolina"
            case .nebraska: return "Nebraska"
            case .newHampshire: return "New Hampshire"
            case .newJersey: return "New Jersey"
            case .newMexico: return "New Mexico"
            case .nevada: return "Nevada"
            case .newYork: return "New York"
            case .ohio: return "Ohio"
            case .oklahoma: return "Oklahoma"
            case .oregon: return "Oregon"
            case .pennsylvania: return "Pennsylvania"
            case .rhodeIsland: return "Rhode Island"
            case .southCarolina: return "South Carolina"
            case .southDakota: return "South Dakota"
            case .tennessee: return "Tennessee"
            case .texas: return "Texas"
            case .utah: return "Utah"
            case .virginia: return "Virginia"
            case .vermont: return "Vermont"
            case .washington: return "Washington"
            case .wisconsin: return "Wisconsin"
            case .westVirginia: return "West Virginia"
            case .wyoming: return "Wyoming"
            }
        }
    }

    public enum CanadianProvince: String, CaseIterable, Hashable, Sendable {
        case britishColumbia = "BC"
        case ontario = "ON"
        public var value: StateValue {
            StateValue(name: name, abbreviation: rawValue)
        }

        public var name: String {
            switch self {
            case .britishColumbia: return "British Columbia"
            case .ontario: return "Ontario"
            }
        }
    }

    public enum Country: String, CaseIterable, Hashable, Sendable {
        case unitedStates = "US"
        case canada = "CA"
        case newZealand = "NZ"
        public var value: CountryValue {
            CountryValue(name: name, abbreviation: rawValue)
        }

        public var name: String {
            switch self {
            case .unitedStates: return "United States"
            case .canada: return "Canada"
            case .newZealand: return "New Zealand"
            }
        }
    }

    public enum NewZealandRegion: String, CaseIterable, Hashable, Sendable {
        case wellington = "Wellington"
        case bayOfPlenty = "Bay of Plenty"
        case westCoast = "West Coast"
        public var value: StateValue {
            StateValue(name: name, abbreviation: rawValue)
        }

        public var name: String {
            switch self {
            case .wellington: return "Wellington"
            case .bayOfPlenty: return "Bay of Plenty"
            case .westCoast: return "West Coast"
            }
        }
    }

    public static func state(from input: String) -> StateValue? {
        if let usValue = USState(rawValue: input) {
            return StateValue(name: usValue.name, abbreviation: input)
        }

        if let caValue = CanadianProvince(rawValue: input) {
            return StateValue(name: caValue.name, abbreviation: input)
        }

        if let nzValue = NewZealandRegion(rawValue: input) {
            return StateValue(name: nzValue.name, abbreviation: input)
        }

        return nil
    }

}

// MARK: - StateValue

/// A struct that represents a state or province.
public struct StateValue: Codable, Equatable, Hashable, Sendable, RawRepresentable {

    // MARK: Lifecycle

    public init(name: String, abbreviation: String) {
        self.name = name
        self.abbreviation = abbreviation
    }

    public init?(rawValue: RawValue) {
        // A dictionary mapping abbreviations to their corresponding name
        let stateMappings: [String: String] = [
            "AK": "Alaska", "AL": "Alabama", "AR": "Arkansas", "AZ": "Arizona",
            "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DC": "District of Columbia",
            "DE": "Delaware", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
            "IA": "Iowa", "ID": "Idaho", "IL": "Illinois", "IN": "Indiana",
            "KS": "Kansas", "LA": "Louisiana", "MA": "Massachusetts", "MD": "Maryland",
            "ME": "Maine", "MI": "Michigan", "MN": "Minnesota", "MO": "Missouri",
            "MS": "Mississippi", "MT": "Montana", "NC": "North Carolina", "NE": "Nebraska",
            "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NV": "Nevada",
            "NY": "New York", "OH": "Ohio", "OK": "Oklahoma", "OR": "Oregon",
            "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota",
            "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VA": "Virginia",
            "VT": "Vermont", "WA": "Washington", "WI": "Wisconsin", "WV": "West Virginia",
            "WY": "Wyoming",
            // Canadian Provinces
            "BC": "British Columbia", "ON": "Ontario",
            // New Zealand Regions
            "Wellington": "Wellington", "Bay of Plenty": "Bay of Plenty", "West Coast": "West Coast"
        ]

        // Check if the provided raw value matches any known abbreviation
        if let stateName = stateMappings[rawValue.uppercased()] {
            self = StateValue(name: stateName, abbreviation: rawValue.uppercased())
        } else {
            return nil
        }
    }

    // MARK: Public

    // RawRepresentable conformance
    public typealias RawValue = String

    public var name: String
    public var abbreviation: String

    public var rawValue: RawValue {
        abbreviation
    }

}

/// A type alias for `StateValue` that represents a country.
public typealias CountryValue = StateValue
