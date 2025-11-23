import Testing
@testable import GaugeSources

@Suite("GaugeSourcesTests")
struct GaugeSourcesTests {
    @Test
    func loadAll_happy() async throws {
        let sources = try await GaugeSources.loadAll()
        #expect(sources.count == 8921) // Includes all regions: CA (BC, ON, QC), US (USGS, DWR), NZ (3 regions)
    }

    @Test
    func loadCanadianProvince_happy() async throws {
        let sources = try await GaugeSources.loadCanadianProvince(.britishColumbia)
        #expect(sources.count == 412)
        #expect(sources.allSatisfy { $0.source == .environmentCanada })
        #expect(sources.allSatisfy { $0.country == "CA" })
    }

    @Test
    func loadUSGS_happy() async throws {
        let sources = try await GaugeSources.loadUSGS()
        #expect(sources.count == 7449)
        #expect(sources.allSatisfy { $0.source == .usgs })
        #expect(sources.allSatisfy { $0.country == "US" })
    }

    @Test
    func loadDWR_happy() async throws {
        let sources = try await GaugeSources.loadDWR()
        #expect(sources.count == 389)
        #expect(sources.allSatisfy { $0.source == .dwr })
        #expect(sources.allSatisfy { $0.country == "US" })
    }

    @Test
    func loadNZRegion_wellington() async throws {
        let sources = try await GaugeSources.loadNZRegion(.wellington)
        #expect(sources.count == 28)
        #expect(sources.allSatisfy { $0.source == .lawa })
        #expect(sources.allSatisfy { $0.country == "NZ" })
    }

    @Test
    func loadNZRegion_bayOfPlenty() async throws {
        let sources = try await GaugeSources.loadNZRegion(.bayOfPlenty)
        #expect(sources.count == 5)
        #expect(sources.allSatisfy { $0.source == .lawa })
    }

    @Test
    func loadNZRegion_westCoast() async throws {
        let sources = try await GaugeSources.loadNZRegion(.westCoast)
        #expect(sources.count == 5)
        #expect(sources.allSatisfy { $0.source == .lawa })
    }

    @Test
    func loadAllNZ_happy() async throws {
        let sources = try await GaugeSources.loadAllNZ()
        #expect(sources.count == 38) // 28 + 5 + 5
        #expect(sources.allSatisfy { $0.source == .lawa })
        #expect(sources.allSatisfy { $0.country == "NZ" })
    }
}
