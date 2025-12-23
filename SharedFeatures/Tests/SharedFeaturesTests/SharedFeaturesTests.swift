//
//  SharedFeaturesTests.swift
//  SharedFeatures
//

import ComposableArchitecture
import Foundation
import GaugeDrivers
import GaugeService
import GaugeSources
import Loadable
import MapKit
import Testing

@testable import SharedFeatures

// MARK: - Test Fixtures

/// Creates a test GaugeRef with sensible defaults
func makeGaugeRef(
    id: Int = 1,
    name: String = "Test Gauge",
    siteID: String = "12345",
    metric: GaugeSourceMetric = .discharge,
    country: String = "US",
    state: String = "WA",
    zone: String = "PST",
    source: GaugeSource = .usgs,
    favorite: Bool = false,
    primary: Bool = true,
    latitude: Double = 47.6062,
    longitude: Double = -122.3321,
    updatedAt: Date = Date(),
    createdAt: Date = Date(),
    status: GaugeOperationalStatus = .active)
-> GaugeRef {
    GaugeRef(
        id: id,
        name: name,
        siteID: siteID,
        metric: metric,
        country: country,
        state: state,
        zone: zone,
        source: source,
        favorite: favorite,
        primary: primary,
        latitude: latitude,
        longitude: longitude,
        updatedAt: updatedAt,
        createdAt: createdAt,
        status: status)
}

/// Creates a test GaugeReadingRef with sensible defaults
func makeGaugeReadingRef(
    id: Int = 1,
    siteID: String = "12345",
    value: Double = 1500.0,
    metric: String = "DISCHARGE",
    gaugeID: Int = 1,
    createdAt: Date = Date())
-> GaugeReadingRef {
    GaugeReadingRef(
        id: id,
        siteID: siteID,
        value: value,
        metric: metric,
        gaugeID: gaugeID,
        createdAt: createdAt)
}

/// Creates a stale GaugeRef (updated more than 30 minutes ago)
func makeStaleGaugeRef(id: Int = 1) -> GaugeRef {
    makeGaugeRef(
        id: id,
        updatedAt: Date().addingTimeInterval(-3600) // 1 hour ago
    )
}

// MARK: - GaugeBotReducerTests

@Suite("GaugeBotReducer Tests")
struct GaugeBotReducerTests {

    @Test("Initial state is correct")
    func initialState() {
        let state = GaugeBotReducer.State()
        #expect(state.messages.isInitial())
        #expect(state.isWaitingForResponse == false)
        #expect(state.inputText == "")
        #expect(state.chatIsPresented == false)
    }

    @Test("setChatPresented updates chatIsPresented state")
    func setChatPresented() async {
        let store = TestStore(initialState: GaugeBotReducer.State()) {
            GaugeBotReducer()
        }

        await store.send(.setChatPresented(true)) {
            $0.chatIsPresented = true
        }

        await store.send(.setChatPresented(false)) {
            $0.chatIsPresented = false
        }
    }

    @Test("setMessages updates messages state")
    func setMessages() async {
        let store = TestStore(initialState: GaugeBotReducer.State()) {
            GaugeBotReducer()
        }

        let messages: [ChatMessage] = [
            .user(UserMessage(content: "Hello")),
            .assistant(AssistantMessage(content: "Hi there!"))
        ]

        await store.send(.setMessages(.loaded(messages))) {
            $0.messages = .loaded(messages)
        }
    }

    @Test("addUserMessage appends user message to messages")
    func addUserMessage() async {
        let store = TestStore(initialState: GaugeBotReducer.State(messages: .loaded([]))) {
            GaugeBotReducer()
        }

        let userMessage = UserMessage(content: "Test message")

        await store.send(.addUserMessage(userMessage)) {
            $0.messages = .loaded([.user(userMessage)])
        }
    }

    @Test("addAssistantMessage appends assistant message and clears waiting flag")
    func addAssistantMessage() async {
        let store = TestStore(
            initialState: GaugeBotReducer.State(
                messages: .loaded([]),
                isWaitingForResponse: true)) {
            GaugeBotReducer()
        }

        let assistantMessage = AssistantMessage(content: "Response")

        await store.send(.addAssistantMessage(assistantMessage)) {
            $0.messages = .loaded([.assistant(assistantMessage)])
            $0.isWaitingForResponse = false
        }
    }

    @Test("sendMessage with empty string does nothing")
    func sendEmptyMessage() async {
        let store = TestStore(initialState: GaugeBotReducer.State()) {
            GaugeBotReducer()
        }

        await store.send(.sendMessage(""))
        await store.send(.sendMessage("   "))
    }

    @Test("responseReceived success adds assistant message")
    func responseReceivedSuccess() async {
        let store = TestStore(
            initialState: GaugeBotReducer.State(
                messages: .loaded([]),
                isWaitingForResponse: true)) {
            GaugeBotReducer()
        }

        await store.send(.responseReceived(.success("Bot response"))) {
            $0.messages = .loaded([
                .assistant(AssistantMessage(content: "Bot response"))
            ])
            $0.isWaitingForResponse = false
        }
    }

    @Test("responseReceived failure adds error message")
    func responseReceivedFailure() async {
        let store = TestStore(
            initialState: GaugeBotReducer.State(
                messages: .loaded([]),
                isWaitingForResponse: true)) {
            GaugeBotReducer()
        }

        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        await store.send(.responseReceived(.failure(error))) {
            $0.messages = .loaded([
                .assistant(AssistantMessage(content: "Error: Test error"))
            ])
            $0.isWaitingForResponse = false
        }
    }
}

// MARK: - FavoriteGaugeTileFeatureTests

@Suite("FavoriteGaugeTileFeature Tests")
struct FavoriteGaugeTileFeatureTests {

    @Test("Initial state is correct")
    func initialState() {
        let gauge = makeGaugeRef()
        let state = FavoriteGaugeTileFeature.State(gauge)

        #expect(state.gauge == gauge)
        #expect(state.readings.isInitial())
    }

    @Test("setReadings updates readings state")
    func setReadings() async {
        let gauge = makeGaugeRef()
        let store = TestStore(initialState: FavoriteGaugeTileFeature.State(gauge)) {
            FavoriteGaugeTileFeature()
        }

        let readings = [makeGaugeReadingRef()]

        await store.send(.setReadings(.loaded(readings))) {
            $0.readings = .loaded(readings)
        }
    }

    @Test("setReadings with error updates state")
    func setReadingsError() async {
        let gauge = makeGaugeRef()
        let store = TestStore(initialState: FavoriteGaugeTileFeature.State(gauge)) {
            FavoriteGaugeTileFeature()
        }

        let error = NSError(domain: "test", code: 1)

        await store.send(.setReadings(.error(error))) {
            $0.readings = .error(error)
        }
    }

    @Test("goToGaugeDetail returns no effect")
    func goToGaugeDetail() async {
        let gauge = makeGaugeRef()
        let store = TestStore(initialState: FavoriteGaugeTileFeature.State(gauge)) {
            FavoriteGaugeTileFeature()
        }

        // goToGaugeDetail is handled by parent reducer
        await store.send(.goToGaugeDetail(1))
    }

    @Test("loadReadings sets loading state and fetches readings")
    func loadReadings() async {
        let gauge = makeGaugeRef()
        let readings = [makeGaugeReadingRef()]

        let store = TestStore(initialState: FavoriteGaugeTileFeature.State(gauge)) {
            FavoriteGaugeTileFeature()
        } withDependencies: {
            $0.gaugeService.loadGaugeReadings = { _ in
                // Return mock Gauge entities - in real code these would be database entities
                // For testing, we simulate the .ref transformation happening in the reducer
                []
            }
        }

        await store.send(.loadReadings) {
            $0.readings = .loading
        }

        // The reducer will send setReadings and then sync
        await store.receive(\.setReadings) {
            $0.readings = .loaded([])
        }

        // sync is concatenated after loadReadings
        await store.receive(\.sync)
    }

    @Test("loadReadings with existing readings shows reloading state")
    func loadReadingsReloading() async {
        let gauge = makeGaugeRef()
        let existingReadings = [makeGaugeReadingRef()]

        let store = TestStore(
            initialState: FavoriteGaugeTileFeature.State(gauge)) {
            FavoriteGaugeTileFeature()
        } withDependencies: {
            $0.gaugeService.loadGaugeReadings = { _ in [] }
        }

        // Set initial loaded state
        await store.send(.setReadings(.loaded(existingReadings))) {
            $0.readings = .loaded(existingReadings)
        }

        await store.send(.loadReadings) {
            $0.readings = .reloading(existingReadings)
        }

        await store.receive(\.setReadings) {
            $0.readings = .loaded([])
        }

        await store.receive(\.sync)
    }

    @Test("sync with fresh gauge does nothing")
    func syncFreshGauge() async {
        let gauge = makeGaugeRef() // Fresh gauge (just updated)

        let store = TestStore(initialState: FavoriteGaugeTileFeature.State(gauge)) {
            FavoriteGaugeTileFeature()
        }

        await store.send(.sync)
        // No effects expected for fresh gauge
    }
}

// MARK: - FavoriteGaugesFeatureTests

@Suite("FavoriteGaugesFeature Tests")
struct FavoriteGaugesFeatureTests {

    @Test("Initial state is correct")
    func initialState() {
        let state = FavoriteGaugesFeature.State()

        #expect(state.gauges.isInitial())
        #expect(state.rows.isEmpty)
        #expect(state.path.isEmpty)
    }

    @Test("setRows updates rows state")
    func setRows() async {
        let store = TestStore(initialState: FavoriteGaugesFeature.State()) {
            FavoriteGaugesFeature()
        }

        let gauge = makeGaugeRef()
        let rows = IdentifiedArrayOf(uniqueElements: [FavoriteGaugeTileFeature.State(gauge)])

        await store.send(.setRows(rows)) {
            $0.rows = rows
        }
    }

    @Test("setGauges updates gauges state")
    func setGauges() async {
        let store = TestStore(initialState: FavoriteGaugesFeature.State()) {
            FavoriteGaugesFeature()
        }

        let gauges = [makeGaugeRef()]

        await store.send(.setGauges(.loaded(gauges))) {
            $0.gauges = .loaded(gauges)
        }
    }

    @Test("load from initial state sets loading")
    func loadFromInitial() async {
        let store = TestStore(initialState: FavoriteGaugesFeature.State()) {
            FavoriteGaugesFeature()
        } withDependencies: {
            $0.gaugeService.loadFavoriteGauges = { [] }
        }

        await store.send(.load) {
            $0.gauges = .loading
        }

        await store.receive(\.setRows) {
            $0.rows = []
        }

        await store.receive(\.setGauges) {
            $0.gauges = .loaded([])
        }
    }

    @Test("load from loaded state sets reloading")
    func loadFromLoaded() async {
        let existingGauges = [makeGaugeRef()]

        let store = TestStore(
            initialState: FavoriteGaugesFeature.State(gauges: .loaded(existingGauges))) {
            FavoriteGaugesFeature()
        } withDependencies: {
            $0.gaugeService.loadFavoriteGauges = { [] }
        }

        await store.send(.load) {
            $0.gauges = .reloading(existingGauges)
        }

        await store.receive(\.setRows) {
            $0.rows = []
        }

        await store.receive(\.setGauges) {
            $0.gauges = .loaded([])
        }
    }

    @Test("load from error state sets loading")
    func loadFromError() async {
        let error = NSError(domain: "test", code: 1)

        let store = TestStore(
            initialState: FavoriteGaugesFeature.State(gauges: .error(error))) {
            FavoriteGaugesFeature()
        } withDependencies: {
            $0.gaugeService.loadFavoriteGauges = { [] }
        }

        await store.send(.load) {
            $0.gauges = .loading
        }

        await store.receive(\.setRows) {
            $0.rows = []
        }

        await store.receive(\.setGauges) {
            $0.gauges = .loaded([])
        }
    }

    @Test("rows action goToGaugeDetail appends to path")
    func rowsGoToGaugeDetail() async {
        let gauge = makeGaugeRef(id: 42)
        let tileState = FavoriteGaugeTileFeature.State(gauge)

        let store = TestStore(
            initialState: FavoriteGaugesFeature.State(
                rows: IdentifiedArrayOf(uniqueElements: [tileState]))) {
            FavoriteGaugesFeature()
        }

        await store.send(.rows(.element(id: tileState.id, action: .goToGaugeDetail(42)))) {
            $0.path.append(.gaugeDetail(GaugeDetailFeature.State(42)))
        }
    }
}

// MARK: - GaugeDetailFeatureTests

@Suite("GaugeDetailFeature Tests")
struct GaugeDetailFeatureTests {

    @Test("Initial state is correct")
    func initialState() {
        let state = GaugeDetailFeature.State(42)

        #expect(state.gaugeID == 42)
        #expect(state.gauge.isInitial())
        #expect(state.readings.isInitial())
        #expect(state.selectedTimePeriod == .last7Days)
        #expect(state.availableMetrics == nil)
        #expect(state.selectedMetric == nil)
        #expect(state.forecast.isInitial())
        #expect(state.forecastAvailable.isInitial())
    }

    @Test("setGauge updates gauge state")
    func setGauge() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        let gauge = makeGaugeRef()

        await store.send(.setGauge(.loaded(gauge))) {
            $0.gauge = .loaded(gauge)
        }
    }

    @Test("setReadings updates readings state")
    func setReadings() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        let readings = [makeGaugeReadingRef()]

        await store.send(.setReadings(.loaded(readings))) {
            $0.readings = .loaded(readings)
        }
    }

    @Test("setSelectedTimePeriod updates time period")
    func setSelectedTimePeriod() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        await store.send(.setSelectedTimePeriod(.last30Days)) {
            $0.selectedTimePeriod = .last30Days
        }
    }

    @Test("setAvailableMetrics updates available metrics")
    func setAvailableMetrics() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        let metrics: [GaugeSourceMetric] = [.discharge, .height]

        await store.send(.setAvailableMetrics(metrics)) {
            $0.availableMetrics = metrics
        }
    }

    @Test("setSelectedMetric updates selected metric")
    func setSelectedMetric() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        await store.send(.setSelectedMetric(.discharge)) {
            $0.selectedMetric = .discharge
        }
    }

    @Test("setForecast updates forecast state")
    func setForecast() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        let forecast = [
            ForecastDataPoint(
                index: Date(),
                value: 1500.0,
                lowerErrorBound: 1400.0,
                upperErrorBound: 1600.0)
        ]

        await store.send(.setForecast(.loaded(forecast))) {
            $0.forecast = .loaded(forecast)
        }
    }

    @Test("setForecastAvailable updates forecastAvailable state")
    func setForecastAvailable() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        await store.send(.setForecastAvailable(.loaded(true))) {
            $0.forecastAvailable = .loaded(true)
        }
    }

    @Test("toggleFavorite with no gauge returns no effect")
    func toggleFavoriteNoGauge() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        await store.send(.toggleFavorite)
    }

    @Test("getForecast without gauge loaded returns no effect")
    func getForecastNoGauge() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        await store.send(.getForecast)
    }

    @Test("getForecast without forecastAvailable returns no effect")
    func getForecastNotAvailable() async {
        let gauge = makeGaugeRef()
        let store = TestStore(
            initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        await store.send(.setGauge(.loaded(gauge))) {
            $0.gauge = .loaded(gauge)
        }

        // forecastAvailable is still initial, so getForecast should do nothing
        await store.send(.getForecast)
    }

    @Test("sync with no gauge logged warning and returns no effect")
    func syncNoGauge() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        }

        await store.send(.sync)
    }

    @Test("loadReadings sets loading state from initial")
    func loadReadingsFromInitial() async {
        let store = TestStore(initialState: GaugeDetailFeature.State(1)) {
            GaugeDetailFeature()
        } withDependencies: {
            $0.gaugeService.loadGaugeReadings = { _ in [] }
        }

        await store.send(.loadReadings) {
            $0.readings = .loading
        }

        await store.receive(\.setAvailableMetrics) {
            $0.availableMetrics = []
        }

        await store.receive(\.setReadings) {
            $0.readings = .loaded([])
        }
    }

    @Test("loadReadings sets reloading state when already loaded")
    func loadReadingsFromLoaded() async {
        let existingReadings = [makeGaugeReadingRef()]

        var state = GaugeDetailFeature.State(1)
        state.readings = .loaded(existingReadings)

        let store = TestStore(initialState: state) {
            GaugeDetailFeature()
        } withDependencies: {
            $0.gaugeService.loadGaugeReadings = { _ in [] }
        }

        await store.send(.loadReadings) {
            $0.readings = .reloading(existingReadings)
        }

        await store.receive(\.setAvailableMetrics) {
            $0.availableMetrics = []
        }

        await store.receive(\.setReadings) {
            $0.readings = .loaded([])
        }
    }
}

// MARK: - GaugeSearchFeatureTests

@Suite("GaugeSearchFeature Tests")
struct GaugeSearchFeatureTests {

    @Test("Initial state is correct")
    func initialState() {
        let state = GaugeSearchFeature.State()

        #expect(state.results.isInitial())
        #expect(state.initialized.isInitial())
        #expect(state.path.isEmpty)
        #expect(state.mapRegion == nil)
        #expect(state.shouldRecenterMap == false)
        #expect(state.searchMode == .viewport)
        #expect(state.filterOptions.hasActiveFilters == false)
        #expect(state.shouldZoomToResults == false)
        #expect(state.inspectorDetail == nil)
    }

    @Test("setResults updates results state")
    func setResults() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        }

        let gauges = [makeGaugeRef()]

        await store.send(.setResults(.loaded(gauges))) {
            $0.results = .loaded(gauges)
        }
    }

    @Test("setQueryOptions updates query options")
    func setQueryOptions() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        }

        let options = GaugeQueryOptions(country: "CA", state: "BC")

        await store.send(.setQueryOptions(options)) {
            $0.queryOptions = options
        }
    }

    @Test("setInitialized updates initialized state")
    func setInitialized() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        }

        await store.send(.setInitialized(.loaded(true))) {
            $0.initialized = .loaded(true)
        }
    }

    @Test("setCurrentLocation with nil previous triggers recenter")
    func setCurrentLocationFirstTime() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        }

        let location = CurrentLocation(latitude: 47.6062, longitude: -122.3321)

        await store.send(.setCurrentLocation(location)) {
            $0.$currentLocation.withLock { $0 = location }
            $0.shouldRecenterMap = true
        }
    }

    @Test("setCurrentLocation with existing location does not recenter")
    func setCurrentLocationSubsequent() async {
        var state = GaugeSearchFeature.State()
        state.$currentLocation.withLock {
            $0 = CurrentLocation(latitude: 40.0, longitude: -100.0)
        }

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        }

        let newLocation = CurrentLocation(latitude: 47.6062, longitude: -122.3321)

        await store.send(.setCurrentLocation(newLocation)) {
            $0.$currentLocation.withLock { $0 = newLocation }
        }
    }

    @Test("recenterOnUserLocation sets shouldRecenterMap when location exists")
    func recenterOnUserLocation() async {
        var state = GaugeSearchFeature.State()
        state.$currentLocation.withLock {
            $0 = CurrentLocation(latitude: 47.6062, longitude: -122.3321)
        }

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        }

        await store.send(.recenterOnUserLocation) {
            $0.shouldRecenterMap = true
        }
    }

    @Test("recenterOnUserLocation without location does nothing")
    func recenterOnUserLocationNoLocation() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        }

        await store.send(.recenterOnUserLocation)
    }

    @Test("recenterCompleted clears shouldRecenterMap")
    func recenterCompleted() async {
        var state = GaugeSearchFeature.State()
        state.shouldRecenterMap = true

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        }

        await store.send(.recenterCompleted) {
            $0.shouldRecenterMap = false
        }
    }

    @Test("goToGaugeDetail appends to path")
    func goToGaugeDetail() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        }

        await store.send(.goToGaugeDetail(42)) {
            $0.path.append(.gaugeDetail(GaugeDetailFeature.State(42)))
        }
    }

    @Test("selectGaugeForInspector creates inspector detail")
    func selectGaugeForInspector() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        } withDependencies: {
            $0.gaugeService.loadGauge = { _ in
                fatalError("Should not be called in this test")
            }
        }

        await store.send(.selectGaugeForInspector(42)) {
            $0.inspectorDetail = GaugeDetailFeature.State(42)
        }

        // Triggers load action on child
        await store.receive(\.inspectorDetail.load)
    }

    @Test("selectGaugeForInspector with same gauge does nothing")
    func selectGaugeForInspectorSameGauge() async {
        var state = GaugeSearchFeature.State()
        state.inspectorDetail = GaugeDetailFeature.State(42)

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        }

        await store.send(.selectGaugeForInspector(42))
    }

    @Test("closeInspector clears inspector detail")
    func closeInspector() async {
        var state = GaugeSearchFeature.State()
        state.inspectorDetail = GaugeDetailFeature.State(42)

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        }

        await store.send(.closeInspector) {
            $0.inspectorDetail = nil
        }
    }

    @Test("setSearchMode from viewport to filtered preserves results")
    func setSearchModeToFiltered() async {
        var state = GaugeSearchFeature.State()
        state.results = .loaded([makeGaugeRef()])

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        }

        await store.send(.setSearchMode(.filtered)) {
            $0.searchMode = .filtered
        }
    }

    @Test("updateFilterOptions updates filter options")
    func updateFilterOptions() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        }

        let options = FilterOptions(country: "US", state: "WA")

        await store.send(.updateFilterOptions(options)) {
            $0.filterOptions = options
        }
    }

    @Test("clearFilters resets filter options and results")
    func clearFilters() async {
        var state = GaugeSearchFeature.State()
        state.filterOptions = FilterOptions(country: "US", state: "WA")
        state.results = .loaded([makeGaugeRef()])

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        }

        await store.send(.clearFilters) {
            $0.filterOptions = FilterOptions()
            $0.results = .loaded([])
        }
    }

    @Test("zoomToResultsCompleted clears shouldZoomToResults")
    func zoomToResultsCompleted() async {
        var state = GaugeSearchFeature.State()
        state.shouldZoomToResults = true

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        }

        await store.send(.zoomToResultsCompleted) {
            $0.shouldZoomToResults = false
        }
    }

    @Test("query from initial state sets loading")
    func queryFromInitial() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        } withDependencies: {
            $0.gaugeService.loadGauges = { _ in [] }
        }

        await store.send(.query) {
            $0.results = .loading
        }

        await store.receive(\.setResults) {
            $0.results = .loaded([])
        }
    }

    @Test("query from loaded state sets reloading")
    func queryFromLoaded() async {
        let existingGauges = [makeGaugeRef()]

        var state = GaugeSearchFeature.State()
        state.results = .loaded(existingGauges)

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        } withDependencies: {
            $0.gaugeService.loadGauges = { _ in [] }
        }

        await store.send(.query) {
            $0.results = .reloading(existingGauges)
        }

        await store.receive(\.setResults) {
            $0.results = .loaded([])
        }
    }

    @Test("setSearchText updates query options and triggers query")
    func setSearchText() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        } withDependencies: {
            $0.gaugeService.loadGauges = { _ in [] }
        }

        await store.send(.setSearchText("Potomac")) {
            var opt = $0.queryOptions
            opt.name = "potomac"
            $0.queryOptions = opt
        }

        await store.receive(\.query) {
            $0.results = .loading
        }

        await store.receive(\.setResults) {
            $0.results = .loaded([])
        }
    }

    @Test("setSearchText with empty string clears name filter")
    func setSearchTextEmpty() async {
        var state = GaugeSearchFeature.State()
        state.queryOptions.name = "existing"

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        } withDependencies: {
            $0.gaugeService.loadGauges = { _ in [] }
        }

        await store.send(.setSearchText("")) {
            var opt = $0.queryOptions
            opt.name = nil
            $0.queryOptions = opt
        }

        await store.receive(\.query) {
            $0.results = .loading
        }

        await store.receive(\.setResults) {
            $0.results = .loaded([])
        }
    }

    @Test("mapRegionChanged in filtered mode does nothing")
    func mapRegionChangedFilteredMode() async {
        var state = GaugeSearchFeature.State()
        state.searchMode = .filtered

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.0, longitude: -122.0),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0))

        await store.send(.mapRegionChanged(region))
    }

    @Test("applyFilters builds query from filter options and triggers query")
    func applyFilters() async {
        var state = GaugeSearchFeature.State()
        state.filterOptions = FilterOptions(country: "US", state: "WA", searchText: "river")

        let store = TestStore(initialState: state) {
            GaugeSearchFeature()
        } withDependencies: {
            $0.gaugeService.loadGauges = { _ in [] }
        }

        await store.send(.applyFilters) {
            $0.queryOptions = GaugeQueryOptions(
                name: "river",
                country: "US",
                state: "WA",
                source: nil,
                boundingBox: nil)
            $0.shouldZoomToResults = true
        }

        await store.receive(\.query) {
            $0.results = .loading
        }

        await store.receive(\.setResults) {
            $0.results = .loaded([])
        }
    }

    @Test("initialize sets initialized to loaded immediately")
    func initializeSuccess() async {
        let store = TestStore(initialState: GaugeSearchFeature.State()) {
            GaugeSearchFeature()
        } withDependencies: {
            $0.locationService = MockLocationService()
        }

        await store.send(.initialize) {
            $0.initialized = .loaded(true)
        }
    }
}

// MARK: - AppFeatureTests

@Suite("AppFeature Tests")
struct AppFeatureTests {

    @Test("Initial state is correct")
    func initialState() {
        let state = AppFeature.State()

        #expect(state.initialized.isInitial())
        #expect(state.selectedTab == .search)
        #expect(state.gaugeSearch == nil)
        #expect(state.favorites == nil)
    }

    @Test("setSelectedTab updates selected tab")
    func setSelectedTab() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.setSelectedTab(.favorites)) {
            $0.selectedTab = .favorites
        }

        await store.send(.setSelectedTab(.search)) {
            $0.selectedTab = .search
        }
    }

    @Test("setInitialized with loaded true creates child states")
    func setInitializedSuccess() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.setInitialized(.loaded(true))) {
            $0.initialized = .loaded(true)
            $0.gaugeSearch = GaugeSearchFeature.State()
            $0.favorites = FavoriteGaugesFeature.State()
        }
    }

    @Test("setInitialized with error does not create child states")
    func setInitializedError() async {
        let error = NSError(domain: "test", code: 1)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.setInitialized(.error(error))) {
            $0.initialized = .error(error)
        }
    }

    @Test("setInitialized with loaded false does not create child states")
    func setInitializedFalse() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.setInitialized(.loaded(false))) {
            $0.initialized = .loaded(false)
        }
    }

    @Test("initialize sets loading state")
    func initializeLoading() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.gaugeService.seeded = { .success(true) }
        }

        await store.send(.initialize) {
            $0.initialized = .loading
        }

        await store.receive(\.setInitialized) {
            $0.initialized = .loaded(true)
            $0.gaugeSearch = GaugeSearchFeature.State()
            $0.favorites = FavoriteGaugesFeature.State()
        }
    }
}

// MARK: - FilterOptionsTests

@Suite("FilterOptions Tests")
struct FilterOptionsTests {

    @Test("hasActiveFilters returns false for empty options")
    func hasActiveFiltersEmpty() {
        let options = FilterOptions()
        #expect(options.hasActiveFilters == false)
    }

    @Test("hasActiveFilters returns true when country is set")
    func hasActiveFiltersCountry() {
        let options = FilterOptions(country: "US")
        #expect(options.hasActiveFilters == true)
    }

    @Test("hasActiveFilters returns true when state is set")
    func hasActiveFiltersState() {
        let options = FilterOptions(state: "WA")
        #expect(options.hasActiveFilters == true)
    }

    @Test("hasActiveFilters returns true when source is set")
    func hasActiveFiltersSource() {
        let options = FilterOptions(source: .usgs)
        #expect(options.hasActiveFilters == true)
    }

    @Test("hasActiveFilters returns true when searchText is non-empty")
    func hasActiveFiltersSearchText() {
        let options = FilterOptions(searchText: "river")
        #expect(options.hasActiveFilters == true)
    }
}

// MARK: - CurrentLocationTests

@Suite("CurrentLocation Tests")
struct CurrentLocationTests {

    @Test("CLLocation conversion is correct")
    func clLocationConversion() {
        let location = CurrentLocation(latitude: 47.6062, longitude: -122.3321)
        let clLocation = location.loc

        #expect(clLocation.coordinate.latitude == 47.6062)
        #expect(clLocation.coordinate.longitude == -122.3321)
    }

    @Test("Equatable works correctly")
    func equatable() {
        let loc1 = CurrentLocation(latitude: 47.6062, longitude: -122.3321)
        let loc2 = CurrentLocation(latitude: 47.6062, longitude: -122.3321)
        let loc3 = CurrentLocation(latitude: 40.0, longitude: -100.0)

        #expect(loc1 == loc2)
        #expect(loc1 != loc3)
    }
}

// MARK: - GaugeRefTests

@Suite("GaugeRef Tests")
struct GaugeRefTests {

    @Test("isStale returns false for fresh gauge")
    func isStaleReturnsFalseForFresh() {
        let gauge = makeGaugeRef(updatedAt: Date())
        #expect(gauge.isStale() == false)
    }

    @Test("isStale returns true for old gauge")
    func isStaleReturnsTrueForOld() {
        let gauge = makeGaugeRef(updatedAt: Date().addingTimeInterval(-3600)) // 1 hour ago
        #expect(gauge.isStale() == true)
    }

    @Test("sourceURL returns correct USGS URL")
    func sourceURLUsgs() {
        let gauge = makeGaugeRef(siteID: "12345", source: .usgs)
        #expect(gauge.sourceURL?.absoluteString.contains("waterdata.usgs.gov") == true)
        #expect(gauge.sourceURL?.absoluteString.contains("12345") == true)
    }

    @Test("sourceURL returns correct DWR URL")
    func sourceURLDwr() {
        let gauge = makeGaugeRef(siteID: "12345", source: .dwr)
        #expect(gauge.sourceURL?.absoluteString.contains("dwr.state.co.us") == true)
        #expect(gauge.sourceURL?.absoluteString.contains("12345") == true)
    }

    @Test("sourceURL returns nil for unsupported source")
    func sourceURLUnsupported() {
        let gauge = makeGaugeRef(source: .lawa)
        #expect(gauge.sourceURL == nil)
    }

    @Test("location returns correct CLLocation")
    func locationProperty() {
        let gauge = makeGaugeRef(latitude: 47.6062, longitude: -122.3321)
        #expect(gauge.location.coordinate.latitude == 47.6062)
        #expect(gauge.location.coordinate.longitude == -122.3321)
    }
}

// MARK: - MockLocationService

@MainActor
final class MockLocationService: LocationServiceProtocol, @unchecked Sendable {
    var currentAuthorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var currentLocation: CLLocation?

    nonisolated func delegate() async -> AsyncStream<LocationManagerDelegateAction> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    nonisolated func requestWhenInUseAuthorization() async { }
    nonisolated func requestLocation() async { }
    nonisolated func startUpdatingLocation() async { }
    nonisolated func stopUpdatingLocation() async { }
}
