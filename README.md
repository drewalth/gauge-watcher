# Gauge Watcher

![Gauge Watcher Hero Image](docs/gw@0.5x.png)

An open source iOS app for monitoring near-real-time river flow gauge data across multiple water resource agencies. This is a complete reboot of the original [GaugeWatcher](https://apps.apple.com/us/app/gaugewatcher/id6498313776) app, rebuilt from scratch to explore iOS 26 and Liquid Glass design patterns.

> This is very much a work in progress. There will be bugs, incomplete features, and other issues. Please report them!

## Features

- **Multi-Source Gauge Data**: Access water flow data from:
  - United States Geological Survey (USGS)
  - Environment Canada (BC, ON, QC)
  - Colorado Department of Water Resources (DWR)
  - Land, Air, Water Aotearoa (LAWA - New Zealand)
- **Interactive Map**: Search and browse gauges by location with visual clustering
- **Historical Charts**: View gauge reading trends over customizable time periods
- **Favorites**: Save frequently monitored gauges for quick access
- **Offline-First Architecture**: Local SQLite database with intelligent caching
- **Location-Aware**: Discover gauges near your current location

## Requirements

- iOS 26.0+ / macOS 26.0+
- Xcode 26.0+
- Swift 6.0+
- Docker
- [openapi-generator](https://openapi-generator.tech/) (for generating the forecast server's Swift client)

## Installation

### Clone the Repository

```bash
git clone https://github.com/drewalth/gauge-watcher.git
cd gauge-watcher
```

### Open in Xcode

```bash
xed .
```

### Start Forecasting Server

```bash
cd server/flow-forecast
./run.sh
```

> If you run into an issue loading the `FlowForecast` Swift package, you may need to run `make generate_clients` to generate the Swift client.


The project uses Swift Package Manager for dependencies. Xcode will automatically resolve and download required packages on first build.

### Dependencies

The project uses the following Swift packages:
- [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture) - App architecture
- [SQLiteData](https://github.com/yourusername/SQLiteData) - Database layer
- Custom local packages for modularity (GaugeSources, GaugeDrivers, AppTelemetry, UIAppearance)

## Building & Running

### Standard Build

Select the `GaugeWatcher` scheme and run (⌘R) in Xcode.

### Testing

Run tests for the entire workspace:
```bash
make test_packages
```

Or run tests directly in Xcode (⌘U).

### Code Quality

Format and lint code:
```bash
make pretty
```

Run linter:
```bash
make lint
```

Check for secrets/leaks:
```bash
make check_leaks
```

## Project Structure

```
gauge-watcher/
├── GaugeWatcher/              # Main iOS app target
│   ├── Feature/               # Feature modules (Search, Detail, Favorites, Settings)
│   ├── Service/               # Business logic services
│   ├── Database/              # Database models and bootstrapping
│   └── Components/            # Reusable UI components
├── GaugeSources/              # Swift package: Gauge data definitions and JSON sources
├── GaugeDrivers/              # Swift package: API clients for each data provider
├── AppTelemetry/              # Swift package: Analytics and tracking
└── UIAppearance/              # Swift package: Shared UI components and styles
```

### Module Responsibilities

- **GaugeWatcher**: Main app container, features, and UI
- **GaugeSources**: Static gauge definitions, state/province configurations
- **GaugeDrivers**: Network clients for fetching live data from each provider's API
- **AppTelemetry**: Event tracking and analytics abstraction
- **UIAppearance**: Design system components, colors, and assets

## Architecture

The app follows **The Composable Architecture (TCA)** pattern:
- Unidirectional data flow
- Pure reducer functions for state management
- Effect-based side effect handling
- Modular feature composition

Key patterns:
- **Repository pattern** for data access (GaugeService, GaugeSourceService)
- **Driver pattern** for API integrations (one driver per data source)
- **Dependency injection** via TCA's dependency system

## Development Workflow

1. **Branch Strategy**: Create feature branches from `main`
2. **Code Style**: Project uses SwiftFormat (Airbnb config) and SwiftLint
3. **Run `make pretty`** before committing to ensure consistent formatting
4. **Write tests** for new gauge drivers and core business logic
5. **Update documentation** for significant changes

## Testing

### Unit Tests
- `GaugeDriversTests/`: Tests for each API driver
- `GaugeSourcesTests/`: Tests for gauge data parsing
- `GaugeWatcherTests/`: App-level integration tests

### Running Tests
```bash
# Test individual packages
swift test --package-path ./GaugeSources
swift test --package-path ./GaugeDrivers

# Or use the convenience target
make test_packages
```

## Contributing

Contributions are welcome! Feel free to open an issue or pull request.

You'll need to install [gitleaks](https://github.com/gitleaks/gitleaks) to check for secrets/leaks in the code before pushing changes.

> Note. This is a small hobby project that is mostly an excuse to learn new things. I'm not looking for a lot of contributions, but I'm happy to accept them if you want to help.
> If you're interested in working on a project with real-world impact, consider contributing to [American Whitewater](https://americanwhitewater.org/).

### Adding New Gauge Sources

1. Add gauge definitions to `GaugeSources/Sources/GaugeSources/Resources/`
2. Implement a new driver in `GaugeDrivers/Sources/GaugeDrivers/`
3. Extend `GaugeDrivers.swift` unified API
4. Add comprehensive tests for your driver
5. Update documentation

## Acknowledgments

- Original GaugeWatcher app concept and design
- Data providers: USGS, Environment Canada, Colorado DWR, LAWA
- The Point-Free team for The Composable Architecture

---

**Status**: Active development | **Version**: 4.0 (reboot) | **Platform**: iOS 18.4+