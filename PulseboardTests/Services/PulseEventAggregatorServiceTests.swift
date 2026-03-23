import Foundation
import XCTest
@testable import Pulseboard

final class PulseEventAggregatorServiceTests: XCTestCase {
    func testFetchEventsMergesSourcesAndSortsBySeverityThenTimestamp() async {
        let olderModerate = makeEvent(
            id: "quake-1",
            category: .earthquakes,
            severity: .moderate,
            source: .usgs,
            timestamp: Date(timeIntervalSince1970: 1000)
        )

        let newerSevere = makeEvent(
            id: "storm-1",
            category: .hazards,
            severity: .severe,
            source: .eonet,
            timestamp: Date(timeIntervalSince1970: 2000)
        )

        let aggregator = PulseEventAggregatorService(
            providers: [
                StubProvider(source: .usgs, mode: .success([olderModerate])),
                StubProvider(source: .eonet, mode: .success([newerSevere]))
            ]
        )

        let result = await aggregator.fetchEvents(in: .days7)

        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(result.events.count, 2)
        XCTAssertEqual(result.events.map(\.id), ["eonet-storm-1", "usgs-quake-1"])
        XCTAssertEqual(result.events.first?.severity, .severe)
    }

    func testFetchEventsReturnsPartialResultsWhenOneSourceFails() async {
        let event = makeEvent(
            id: "hazard-1",
            category: .hazards,
            severity: .high,
            source: .eonet,
            timestamp: Date(timeIntervalSince1970: 3000)
        )

        let aggregator = PulseEventAggregatorService(
            providers: [
                StubProvider(source: .eonet, mode: .success([event])),
                StubProvider(source: .usgs, mode: .failure("USGS unavailable"))
            ]
        )

        let result = await aggregator.fetchEvents(in: .hours24)

        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events.first?.id, "eonet-hazard-1")
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures.first?.source, .usgs)
    }

    private func makeEvent(
        id: String,
        category: PulseCategory,
        severity: PulseSeverity,
        source: PulseSource,
        timestamp: Date
    ) -> PulseEvent {
        PulseEvent(
            id: id,
            title: id,
            summary: "summary",
            category: category,
            severity: severity,
            source: source,
            timestamp: timestamp,
            coordinate: PulseCoordinate(latitude: 10, longitude: 20),
            link: nil,
            metadata: [:]
        )
    }
}

private actor StubProvider: PulseEventProviding {
    enum Mode {
        case success([PulseEvent])
        case failure(String)
    }

    let source: PulseSource
    private let mode: Mode

    init(source: PulseSource, mode: Mode) {
        self.source = source
        self.mode = mode
    }

    func fetchEvents(in timeWindow: PulseTimeWindow) async throws -> [PulseEvent] {
        switch mode {
        case let .success(events):
            return events
        case let .failure(message):
            throw StubProviderError(message: message)
        }
    }
}

private struct StubProviderError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
