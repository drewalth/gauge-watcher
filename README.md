# Gauge Watcher

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

![Gauge Watcher Hero Image](docs/gw@0.5x.png)

An iOS and macOS app for monitoring near-real-time river flow gauge data across multiple water resource agencies. This is a complete reboot of the original [GaugeWatcher](https://apps.apple.com/us/app/gaugewatcher/id6498313776) app, rebuilt from scratch to explore iOS 26, macOS 26, and SwiftData alternatives.

> This is very much a work in progress. There will be bugs, incomplete features, and other issues. Please report them!

## Features

- **Multi-Source Gauge Data**: Access water flow data from:
  - United States Geological Survey (USGS)
  - Environment Canada (BC, ON, QC)
  - Colorado Department of Water Resources (DWR)
  - Land, Air, Water Aotearoa (LAWA - New Zealand)
- **GaugeBot AI Assistant** (macOS): Chat with an on-device AI assistant powered by Apple Intelligence to search gauges, check favorites, and get information about water conditions using natural language
- **Interactive Map**: Search and browse gauges by location with visual clustering
- **Historical Charts**: View gauge reading trends over customizable time periods
- **Favorites**: Save frequently monitored gauges for quick access
- **Offline-First Architecture**: Local SQLite database with intelligent caching
- **Location-Aware**: Discover gauges near your current location

## GaugeBot AI Assistant

GaugeBot is an on-device AI chat assistant powered by Apple Intelligence and the Foundation Models framework. It provides a natural language interface to explore and manage water gauges.

### Capabilities

- **Search Gauges**: Ask questions like "Find gauges on the Arkansas River" or "What gauges are in Colorado?"
- **Check Favorites**: Query your saved gauges with "Show me my favorite gauges" or "What are my saved stations?"
- **Get Information**: Ask about specific rivers, locations, or gauge data

### Requirements

GaugeBot requires:
- **macOS 26.0+** (Apple Silicon)
- **Apple Intelligence** enabled on your device
- The on-device language model must be downloaded (happens automatically when Apple Intelligence is enabled)

> GaugeBot runs entirely on-device using Apple's Foundation Models framework. No data is sent to external AI services - all processing happens locally on your Mac.

### Availability

GaugeBot is currently available on **macOS only**. The feature gracefully degrades on unsupported devices or when Apple Intelligence is not enabled, showing helpful guidance on how to enable it.

## Requirements

- iOS 26.0+ / macOS 26.0+
- Xcode 26.0+
- Swift 6.0+
- Docker
- [openapi-generator](https://openapi-generator.tech/) (for generating the forecast server's Swift client)
- Apple Intelligence enabled (for GaugeBot on macOS)

## Installation

### Clone the Repository

```bash
git clone https://github.com/drewalth/gauge-watcher.git
cd gauge-watcher
```

### Configuration

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Configure analytics (optional):**
   Edit `.env` and add your PostHog credentials if you want analytics:
   ```
   POSTHOG_API_KEY=phc_your_api_key_here
   POSTHOG_HOST=https://us.i.posthog.com
   ```
   > The app works without analytics configured - telemetry will simply be disabled.

3. **Run the setup script:**
   ```bash
   ./scripts/setup.sh
   ```

### Open in Xcode

```bash
xed .
```

### Configure Development Team

Before building, you'll need to set your Apple Development Team:

1. Open the project in Xcode
2. Select the `GaugeWatcher` target
3. Go to **Signing & Capabilities**
4. Select your Development Team from the dropdown

### Flow Forecast Server (Optional)

The app includes a flow forecasting feature for USGS gauges that requires a local Python server.

```bash
cd server/flow-forecast
./run.sh
```

The server runs on `http://localhost:8000` by default. If you don't run the forecast server, the app will still work - the forecast feature will simply show as unavailable for gauges.

> If you run into an issue loading the `FlowForecast` Swift package, you may need to run `make generate_clients` from the `server/flow-forecast` directory to regenerate the Swift client.

The project uses Swift Package Manager for dependencies. Xcode will automatically resolve and download required packages on first build.

### Dependencies

The project uses the following Swift packages:
- [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture) - App architecture
- [SQLiteData](https://github.com/pointfreeco/sqlite-data) - Database layer
- Custom local packages for modularity (GaugeSources, GaugeDrivers, AppTelemetry, UIAppearance)

## Building & Running

### iOS

Select the `GaugeWatcher` scheme and run (⌘R) in Xcode.

### macOS

Select the `GaugeWatcherMac` scheme and run (⌘R) in Xcode. The macOS app features a sidebar/detail layout with an interactive full-screen map.

### Testing

Run tests for the Swift packages:
```bash
./scripts/test.sh
```

Or run tests directly in Xcode (⌘U).

### Code Quality

Format and lint code:
```bash
./scripts/format.sh
```

Run linter only:
```bash
./scripts/lint.sh
```

Check for secrets/leaks:
```bash
./scripts/check-leaks.sh
```

## Project Structure

```
gauge-watcher/
├── GaugeWatcher/              # Main iOS app target
│   ├── Feature/               # Feature modules (Search, Detail, Favorites, Settings)
│   ├── Service/               # Business logic services
│   ├── Database/              # Database models and bootstrapping
│   └── Components/            # Reusable UI components
├── GaugeWatcherMac/           # Native macOS app target
│   ├── Feature/               # macOS-optimized feature modules
│   └── Service/               # macOS-specific services
├── SharedFeatures/            # Swift package: Shared TCA features and state
├── GaugeBot/                  # Swift package: AI assistant using Apple Intelligence
├── GaugeSources/              # Swift package: Gauge data definitions and JSON sources
├── GaugeDrivers/              # Swift package: API clients for each data provider
├── GaugeService/              # Swift package: Database and data access layer
├── AppDatabase/               # Swift package: SQLite schema and migrations
├── AppTelemetry/              # Swift package: Analytics and tracking
├── UIAppearance/              # Swift package: Shared UI components and styles
└── UIComponents/              # Swift package: Reusable SwiftUI components
```

### Module Responsibilities

- **GaugeWatcher**: Main iOS app container, features, and UI
- **GaugeWatcherMac**: Native macOS app with NavigationSplitView layout, full-screen map, and platform-specific optimizations
- **SharedFeatures**: Cross-platform TCA reducers, state management, and business logic shared between iOS and macOS
- **GaugeBot**: On-device AI assistant using Apple Intelligence Foundation Models framework (macOS only)
- **GaugeSources**: Static gauge definitions, state/province configurations
- **GaugeDrivers**: Network clients for fetching live data from each provider's API
- **GaugeService**: Database queries, data synchronization, and business logic
- **AppDatabase**: SQLite schema definitions using SQLiteData
- **AppTelemetry**: Event tracking and analytics abstraction
- **UIAppearance**: Design system components, colors, and assets
- **UIComponents**: Reusable SwiftUI view components

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
3. **Run `./scripts/format.sh`** before committing to ensure consistent formatting
4. **Write tests** for new gauge drivers and core business logic
5. **Update documentation** for significant changes

## Testing

### Unit Tests
- `GaugeDriversTests/`: Tests for each API driver
- `GaugeSourcesTests/`: Tests for gauge data parsing
- `GaugeWatcherTests/`: iOS app integration tests
- `GaugeWatcherMacTests/`: macOS app integration tests
- `SharedFeaturesTests/`: Cross-platform feature tests

### Running Tests
```bash
# Test all packages
./scripts/test.sh

# Or test individual packages
swift test --package-path ./GaugeSources
swift test --package-path ./GaugeDrivers
```

## Contributing

Contributions are welcome! Feel free to open an issue or pull request. **But please note**, this is a small hobby project that is mostly an excuse to learn new things.
I'm not looking for a lot of contributions, but I'm happy to accept them if you want to help. If you're interested in working on a project with real-world impact, 
consider contributing to [American Whitewater](https://americanwhitewater.org/), [Whitewater NZ](https://whitewater.nz), or [BC Whitewater](https://www.bcwhitewater.org).

You'll need to install [gitleaks](https://github.com/gitleaks/gitleaks) to check for secrets/leaks in the code before pushing changes.

### Adding New Gauge Sources

1. Add gauge definitions to `GaugeSources/Sources/GaugeSources/Resources/`
2. Implement a new driver in `GaugeDrivers/Sources/GaugeDrivers/`
3. Extend `GaugeDrivers.swift` unified API
4. Add comprehensive tests for your driver
5. Update documentation

## Data Sources

- [USGS](https://waterservices.usgs.gov)
- [Environment Canada](https://dd.weather.gc.ca)
- [Colorado DWR](https://dwr.state.co.us/Tools)
- [Land, Air, Water Aotearoa (LAWA)](https://www.lawa.org.nz)

## Acknowledgments

- [@ajbonich](https://github.com/ajbonich) initial forecasting server implementation.
- [@ngottlieb](https://github.com/ngottlieb) Canadian gauge data guidance.