# GaugeDrivers Unified API

## Overview

The refactored `GaugeDrivers` package provides a **standardized, unified interface** for fetching gauge readings from multiple data sources (USGS, Environment Canada, Colorado DWR, and LAWA).

## Core Concepts

### 1. `GaugeDriver` Protocol
All data source drivers conform to this protocol:
```swift
public protocol GaugeDriver: Sendable {
    func fetchReadings(options: GaugeDriverOptions) async throws -> [GDGaugeReading]
    func fetchReadings(optionsArray: [GaugeDriverOptions]) async throws -> [GDGaugeReading]
}
```

### 2. `GaugeDriverOptions`
Unified options that work across all sources:
```swift
public struct GaugeDriverOptions: Sendable {
    public let siteID: String
    public let source: GaugeDriverSource
    public let timePeriod: TimePeriod
    public let parameters: [ReadingParameter]
    public let metadata: SourceMetadata?
}
```

### 3. `GaugeDriverFactory`
Factory for creating and managing drivers:
```swift
let factory = GaugeDriverFactory()
let readings = try await factory.fetchReadings(options: options)
```

## Usage Examples

### Basic Usage: Single Gauge

```swift
import GaugeDrivers

// Create options for a USGS gauge
let options = GaugeDriverOptions(
    siteID: "09380000",
    source: .usgs,
    timePeriod: .predefined(.last7Days),
    parameters: [.discharge, .height]
)

// Fetch readings
let factory = GaugeDriverFactory()
let readings = try await factory.fetchReadings(options: options)

// Process results
for reading in readings {
    print("\(reading.timestamp): \(reading.value) \(reading.unit.rawValue)")
}
```

### Environment Canada (Requires Province Metadata)

```swift
let options = GaugeDriverOptions(
    siteID: "07EA004",
    source: .environmentCanada,
    timePeriod: .predefined(.last24Hours),
    parameters: [.discharge, .height],
    metadata: .environmentCanada(province: .bc)
)

let readings = try await factory.fetchReadings(options: options)
```

### Colorado DWR

```swift
let options = GaugeDriverOptions(
    siteID: "0200616A",
    source: .dwr,
    timePeriod: .predefined(.last7Days),
    parameters: [.discharge]
)

let readings = try await factory.fetchReadings(options: options)
```

### Batch Fetching Multiple Gauges

```swift
let optionsArray = [
    GaugeDriverOptions(
        siteID: "09380000",
        source: .usgs,
        timePeriod: .predefined(.last7Days),
        parameters: [.discharge]
    ),
    GaugeDriverOptions(
        siteID: "09379000",
        source: .usgs,
        timePeriod: .predefined(.last7Days),
        parameters: [.discharge]
    ),
    GaugeDriverOptions(
        siteID: "07EA004",
        source: .environmentCanada,
        timePeriod: .predefined(.last7Days),
        parameters: [.discharge],
        metadata: .environmentCanada(province: .bc)
    )
]

// Fetches all in parallel, automatically grouping by source
let allReadings = try await factory.fetchReadings(optionsArray: optionsArray)
```

### Custom Time Periods

```swift
// Predefined periods
let last24Hours = TimePeriod.predefined(.last24Hours)
let last7Days = TimePeriod.predefined(.last7Days)
let last30Days = TimePeriod.predefined(.last30Days)
let last90Days = TimePeriod.predefined(.last90Days)

// Custom date range
let startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
let endDate = Date()
let customPeriod = TimePeriod.custom(start: startDate, end: endDate)

let options = GaugeDriverOptions(
    siteID: "09380000",
    source: .usgs,
    timePeriod: customPeriod,
    parameters: [.discharge]
)
```

### Direct Driver Access (Advanced)

```swift
// Get a specific driver directly
let factory = GaugeDriverFactory()
let usgsDriver = factory.driver(for: .usgs) as! GDUnitedStatesGeologicalSurvey

// Use the unified API
let options = GaugeDriverOptions(...)
let readings = try await usgsDriver.fetchReadings(options: options)

// Or use the legacy API (still supported)
let legacyReadings = try await usgsDriver.fetchGaugeStationData(
    siteID: "09380000",
    timePeriod: .predefined(.last7Days),
    parameters: [.discharge]
)
```

## Integration with GaugeSources

If you're using the `GaugeSources` package for gauge metadata, add this bridge extension to your app:

```swift
import GaugeSources
import GaugeDrivers

extension GaugeSourceItem {
    func toDriverOptions(
        timePeriod: TimePeriod = .predefined(.last7Days),
        parameters: [ReadingParameter] = ReadingParameter.allCases
    ) -> GaugeDriverOptions? {
        guard let source = self.source else { return nil }
        
        let metadata: SourceMetadata? = {
            switch source {
            case .environmentCanada:
                let provinceCode = state.lowercased()
                guard let province = EnvironmentCanada.Province(rawValue: provinceCode) else {
                    return nil
                }
                return .environmentCanada(province: province)
            case .usgs, .dwr, .lawa:
                return nil
            }
        }()
        
        return GaugeDriverOptions(
            siteID: siteID,
            source: source.toDriverSource,
            timePeriod: timePeriod,
            parameters: parameters,
            metadata: metadata
        )
    }
    
    func fetchReadings(
        timePeriod: TimePeriod = .predefined(.last7Days),
        parameters: [ReadingParameter] = ReadingParameter.allCases
    ) async throws -> [GDGaugeReading] {
        guard let options = toDriverOptions(timePeriod: timePeriod, parameters: parameters) else {
            throw GaugeDriverErrors.invalidOptions("Unable to create options")
        }
        return try await GaugeDriverFactory().fetchReadings(options: options)
    }
}
```

Then use it like this:

```swift
// Load gauge metadata
let gauges = try await GaugeSources.loadAll()

// Fetch readings for a single gauge
let gauge = gauges.first!
let readings = try await gauge.fetchReadings()

// Fetch readings for multiple gauges
let readings = try await gauges.fetchReadings(
    timePeriod: .predefined(.last7Days),
    parameters: [.discharge]
)
```

## Error Handling

```swift
do {
    let readings = try await factory.fetchReadings(options: options)
} catch let error as GaugeDriverErrors {
    switch error {
    case .missingRequiredMetadata(let detail):
        print("Missing metadata: \(detail)")
    case .unsupportedParameter(let param, let source):
        print("\(param) not supported by \(source)")
    case .invalidOptions(let detail):
        print("Invalid options: \(detail)")
    }
} catch let error as GDUnitedStatesGeologicalSurvey.Errors {
    // Handle USGS-specific errors
} catch let error as GDEnvironmentCanada.Errors {
    // Handle Environment Canada-specific errors
} catch {
    print("Unexpected error: \(error)")
}
```

## Migration from Old API

### Before (Inconsistent APIs)

```swift
// USGS - one way
let usgsAPI = USGS()
let usgsReadings = try await usgsAPI.fetchGaugeStationData(
    siteID: "09380000",
    timePeriod: .predefined(.last7Days),
    parameters: [.discharge]
)

// Environment Canada - different way
let envCanada = EnvironmentCanada()
let envReadings = try await envCanada.fetchGaugeStationData(
    siteID: "07EA004",
    province: .bc
)

// DWR - yet another way
let dwr = DWR()
let dwrReadings = try await dwr.fetchData("0200616A")
```

### After (Unified API)

```swift
let factory = GaugeDriverFactory()

// All sources use the same API
let usgsReadings = try await factory.fetchReadings(
    options: GaugeDriverOptions(siteID: "09380000", source: .usgs)
)

let envReadings = try await factory.fetchReadings(
    options: GaugeDriverOptions(
        siteID: "07EA004",
        source: .environmentCanada,
        metadata: .environmentCanada(province: .bc)
    )
)

let dwrReadings = try await factory.fetchReadings(
    options: GaugeDriverOptions(siteID: "0200616A", source: .dwr)
)
```

## Benefits

1. **Single API** - One method signature for all data sources
2. **Type Safety** - Strongly typed options and errors
3. **Parallel Fetching** - Automatic batching and parallelization
4. **Easy Testing** - Mock the factory or individual drivers
5. **Extensible** - Add new sources by conforming to `GaugeDriver`
6. **Backward Compatible** - Legacy APIs still work (deprecated)

## Performance

The unified API automatically optimizes batch requests:
- Groups by source for efficient API calls
- Fetches multiple gauges in parallel
- Respects source-specific limits (e.g., USGS 100-site limit)

```swift
// This automatically:
// 1. Groups USGS gauges together
// 2. Groups Environment Canada gauges by province
// 3. Fetches each group in parallel
let readings = try await factory.fetchReadings(optionsArray: mixedSourceOptions)
```

