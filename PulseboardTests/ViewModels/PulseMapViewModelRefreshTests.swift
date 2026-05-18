import Foundation
import XCTest
@testable import Pulseboard

@MainActor
final class PulseMapViewModelRefreshTests: XCTestCase {
    func testLatestTimeWindowSelectionWinsOverOlderInFlightRefresh() async {
        let slowHours24Event = makeEvent(
            id: "slow-hours24",
            timestamp: Date(timeIntervalSince1970: 1_000)
        )
        let fastDays7Event = makeEvent(
            id: "fast-days7",
            timestamp: Date(timeIntervalSince1970: 2_000)
        )

        let provider = TimeWindowStubProvider(
            source: .usgs,
            responses: [
                .hours24: .success([slowHours24Event], delayMilliseconds: 280),
                .days7: .success([fastDays7Event], delayMilliseconds: 25)
            ]
        )
        let aggregator = PulseEventAggregatorService(providers: [provider])
        let viewModel = PulseMapViewModel(eventAggregator: aggregator)

        let oldRefreshTask = Task {
            await viewModel.refresh()
        }
        try? await Task.sleep(nanoseconds: 40_000_000)

        viewModel.select(timeWindow: .days7)
        await oldRefreshTask.value
        await waitUntilIdle(viewModel)

        XCTAssertEqual(viewModel.selectedTimeWindow, .days7)
        XCTAssertEqual(viewModel.filteredEvents.count, 1)
        XCTAssertEqual(viewModel.filteredEvents.first?.id, "usgs-fast-days7")
    }

    func testSuccessfulEmptyRefreshClearsPreviouslyDisplayedEvents() async {
        let initialEvent = makeEvent(
            id: "initial",
            timestamp: Date(timeIntervalSince1970: 3_000)
        )

        let provider = TimeWindowStubProvider(
            source: .usgs,
            responses: [
                .hours24: .success([initialEvent], delayMilliseconds: 10),
                .days7: .success([], delayMilliseconds: 10)
            ]
        )
        let aggregator = PulseEventAggregatorService(providers: [provider])
        let viewModel = PulseMapViewModel(eventAggregator: aggregator)

        await viewModel.refresh()
        XCTAssertEqual(viewModel.filteredEvents.count, 1)
        XCTAssertEqual(viewModel.metrics.totalCount, 1)

        viewModel.select(timeWindow: .days7)
        await waitForCondition {
            viewModel.selectedTimeWindow == .days7 && !viewModel.isLoading && viewModel.filteredEvents.isEmpty
        }

        XCTAssertEqual(viewModel.selectedTimeWindow, .days7)
        XCTAssertTrue(viewModel.filteredEvents.isEmpty)
        XCTAssertTrue(viewModel.featuredEvents.isEmpty)
        XCTAssertTrue(viewModel.mapItems.isEmpty)
        XCTAssertEqual(viewModel.metrics.totalCount, 0)
    }

    func testAlertCategoryFiltersNWSAlertsAndUpdatesMetrics() async {
        let now = Date()
        let earthquake = makeEvent(
            id: "earthquake",
            category: .earthquakes,
            severity: .moderate,
            source: .usgs,
            timestamp: now
        )
        let nwsAlert = makeEvent(
            id: "nws-alert",
            category: .alerts,
            severity: .high,
            source: .nws,
            timestamp: now
        )
        let gdacsHazard = makeEvent(
            id: "gdacs-hazard",
            category: .hazards,
            severity: .low,
            source: .gdacs,
            timestamp: now.addingTimeInterval(-8 * 60 * 60)
        )

        let aggregator = PulseEventAggregatorService(
            providers: [
                TimeWindowStubProvider(
                    source: .usgs,
                    responses: [.hours24: .success([earthquake], delayMilliseconds: 0)]
                ),
                TimeWindowStubProvider(
                    source: .nws,
                    responses: [.hours24: .success([nwsAlert], delayMilliseconds: 0)]
                ),
                TimeWindowStubProvider(
                    source: .gdacs,
                    responses: [.hours24: .success([gdacsHazard], delayMilliseconds: 0)]
                )
            ]
        )
        let viewModel = PulseMapViewModel(eventAggregator: aggregator)

        await viewModel.refresh()
        XCTAssertEqual(viewModel.metrics.totalCount, 3)

        viewModel.selectedCategory = .alerts

        XCTAssertEqual(viewModel.filteredEvents.map(\.id), ["nws-nws-alert"])
        XCTAssertEqual(viewModel.filteredEvents.first?.source, .nws)
        XCTAssertEqual(viewModel.metrics.totalCount, 1)
        XCTAssertEqual(viewModel.metrics.severeCount, 1)
        XCTAssertEqual(viewModel.metrics.recentCount, 1)
    }

    func testSelectedRegionRemainsFilterSourceOfTruth() async {
        let northAmericaEvent = makeEvent(
            id: "north-america",
            category: .earthquakes,
            severity: .moderate,
            source: .usgs,
            timestamp: Date(),
            coordinate: PulseCoordinate(latitude: 37.7749, longitude: -122.4194)
        )
        let europeEvent = makeEvent(
            id: "europe",
            category: .earthquakes,
            severity: .moderate,
            source: .usgs,
            timestamp: Date(),
            coordinate: PulseCoordinate(latitude: 48.8566, longitude: 2.3522)
        )

        let aggregator = PulseEventAggregatorService(
            providers: [
                TimeWindowStubProvider(
                    source: .usgs,
                    responses: [.hours24: .success([northAmericaEvent, europeEvent], delayMilliseconds: 0)]
                )
            ]
        )
        let viewModel = PulseMapViewModel(eventAggregator: aggregator)

        await viewModel.refresh()
        XCTAssertEqual(viewModel.selectedRegion, .world)
        XCTAssertEqual(viewModel.filteredEvents.map(\.id).sorted(), ["usgs-europe", "usgs-north-america"])

        viewModel.selectedRegion = .northAmerica

        XCTAssertEqual(viewModel.selectedRegion, .northAmerica)
        XCTAssertEqual(viewModel.filteredEvents.map(\.id), ["usgs-north-america"])
        XCTAssertEqual(viewModel.metrics.totalCount, 1)
    }

    private func waitUntilIdle(_ viewModel: PulseMapViewModel) async {
        await waitForCondition { !viewModel.isLoading }
        XCTAssertFalse(viewModel.isLoading, "Expected refresh to complete before timeout.")
    }

    private func waitForCondition(_ condition: @escaping () -> Bool) async {
        let timeoutDate = Date().addingTimeInterval(2)

        while !condition(), Date() < timeoutDate {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "Expected condition to become true before timeout.")
    }

    private func makeEvent(
        id: String,
        category: PulseCategory = .earthquakes,
        severity: PulseSeverity = .moderate,
        source: PulseSource = .usgs,
        timestamp: Date,
        coordinate: PulseCoordinate = PulseCoordinate(latitude: 37.7749, longitude: -122.4194)
    ) -> PulseEvent {
        PulseEvent(
            id: id,
            title: id,
            summary: "summary",
            category: category,
            severity: severity,
            source: source,
            timestamp: timestamp,
            coordinate: coordinate,
            link: nil,
            metadata: [:]
        )
    }
}

private actor TimeWindowStubProvider: PulseEventProviding {
    enum Response {
        case success([PulseEvent], delayMilliseconds: UInt64)
        case failure(String, delayMilliseconds: UInt64)
    }

    let source: PulseSource
    private let responses: [PulseTimeWindow: Response]

    init(source: PulseSource, responses: [PulseTimeWindow: Response]) {
        self.source = source
        self.responses = responses
    }

    func fetchEvents(in timeWindow: PulseTimeWindow) async throws -> [PulseEvent] {
        let response = responses[timeWindow] ?? .success([], delayMilliseconds: 0)

        switch response {
        case let .success(events, delayMilliseconds):
            try await pause(milliseconds: delayMilliseconds)
            return events
        case let .failure(message, delayMilliseconds):
            try await pause(milliseconds: delayMilliseconds)
            throw TimeWindowStubProviderError(message: message)
        }
    }

    private func pause(milliseconds: UInt64) async throws {
        guard milliseconds > 0 else {
            return
        }
        try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    }
}

private struct TimeWindowStubProviderError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
