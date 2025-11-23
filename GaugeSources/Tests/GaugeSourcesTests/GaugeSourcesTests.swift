import Testing
@testable import GaugeSources

@Suite("GaugeSourcesTests")
struct GaugeSourcesTests {
    @Test
    func loadAll_happy() async throws {
        let sources = try await GaugeSources.loadAll()
        #expect(sources.count == 8891)
    }

    @Test
    func loadCanadianProvince_happy() async throws {
        let sources = try await GaugeSources.loadCanadianProvince(.britishColumbia)
        #expect(sources.count == 412)
    }

    @Test
    func loadUSGS_happy() async throws {
        let sources = try await GaugeSources.loadUSGS()
        #expect(sources.count == 7457)
    }

    @Test
    func loadDWR_happy() async throws {
        let sources = try await GaugeSources.loadDWR()
        #expect(sources.count == 389)
    }

    @Test
    func loadLAWA_happy() async throws {
        await #expect(throws: GaugeSourceError.self) {
            try await GaugeSources.loadLAWA()
        }
    }
}
