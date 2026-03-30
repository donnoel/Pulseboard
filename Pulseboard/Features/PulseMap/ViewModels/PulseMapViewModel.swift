import Combine
import Foundation
import OSLog

struct PulseMapItem: Identifiable, Sendable {
    let id: String
    let coordinate: PulseCoordinate
    let events: [PulseEvent]

    var count: Int { events.count }
    var primaryEvent: PulseEvent { events[0] }
    var isCluster: Bool { count > 1 }
}

struct PulseSummaryMetrics: Sendable {
    let totalCount: Int
    let severeCount: Int
    let recentCount: Int

    static let empty = PulseSummaryMetrics(totalCount: 0, severeCount: 0, recentCount: 0)
}

@MainActor
final class PulseMapViewModel: ObservableObject {
    @Published private(set) var filteredEvents: [PulseEvent] = []
    @Published private(set) var mapItems: [PulseMapItem] = []
    @Published private(set) var featuredEvents: [PulseEvent] = []
    @Published private(set) var metrics: PulseSummaryMetrics = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?

    @Published var selectedRegion: PulseRegion = .world {
        didSet { applyFilters() }
    }

    @Published var selectedCategory: PulseCategory = .all {
        didSet { applyFilters() }
    }

    @Published private(set) var selectedTimeWindow: PulseTimeWindow = .hours24

    private let eventAggregator: PulseEventAggregatorService
    private let logger = Logger(subsystem: "dn.pulseboard", category: "PulseMapViewModel")
    private var allEvents: [PulseEvent] = []
    private var refreshTask: Task<PulseEventAggregationResult, Never>?
    private var refreshRequestID: UInt64 = 0

    init(eventAggregator: PulseEventAggregatorService = PulseEventAggregatorService()) {
        self.eventAggregator = eventAggregator
    }

    func loadIfNeeded() async {
        guard allEvents.isEmpty else {
            return
        }

        await refresh()
    }

    func select(timeWindow: PulseTimeWindow) {
        guard timeWindow != selectedTimeWindow else {
            return
        }

        selectedTimeWindow = timeWindow
        Task {
            await refresh()
        }
    }

    func refresh() async {
        refreshTask?.cancel()
        refreshRequestID &+= 1
        let requestID = refreshRequestID
        let targetTimeWindow = selectedTimeWindow
        isLoading = true

        let task = Task { [eventAggregator] in
            await eventAggregator.fetchEvents(in: targetTimeWindow)
        }
        refreshTask = task
        let result = await task.value

        guard requestID == refreshRequestID else {
            return
        }

        refreshTask = nil
        isLoading = false

        if result.hasFailures {
            let failedSources = result.failures.map { $0.source.title }.joined(separator: ", ")
            logger.error("Some source feeds failed: \(failedSources, privacy: .public)")
            errorMessage = result.hasSuccessfulSources
                ? "Some feeds are unavailable (\(failedSources)). Showing available live data."
                : "Live event feeds are temporarily unavailable (\(failedSources)). Pull to retry."
        } else {
            errorMessage = nil
        }

        guard result.hasSuccessfulSources else {
            if filteredEvents.isEmpty {
                metrics = .empty
            }
            return
        }

        allEvents = result.events
        lastUpdated = Date.now
        applyFilters()
    }

    func dismissError() {
        errorMessage = nil
    }

    private func applyFilters() {
        let categoryEvents: [PulseEvent]
        if selectedCategory == .all {
            categoryEvents = allEvents
        } else {
            categoryEvents = allEvents.filter { $0.category == selectedCategory }
        }

        let regionEvents = categoryEvents.filter { selectedRegion.contains($0.coordinate) }
        filteredEvents = regionEvents.sorted(by: sortEvents(lhs:rhs:))

        featuredEvents = Array(filteredEvents.prefix(10))
        mapItems = Self.clusteredMapItems(from: filteredEvents, region: selectedRegion)
        metrics = PulseSummaryMetrics(
            totalCount: filteredEvents.count,
            severeCount: filteredEvents.filter { $0.severity.rank >= PulseSeverity.high.rank }.count,
            recentCount: filteredEvents.filter { Date.now.timeIntervalSince($0.timestamp) <= 6 * 60 * 60 }.count
        )
    }

    private func sortEvents(lhs: PulseEvent, rhs: PulseEvent) -> Bool {
        if lhs.severity.rank != rhs.severity.rank {
            return lhs.severity.rank > rhs.severity.rank
        }
        return lhs.timestamp > rhs.timestamp
    }

    private static func clusteredMapItems(from events: [PulseEvent], region: PulseRegion) -> [PulseMapItem] {
        let gridSize = clusterGridSize(for: region)
        var buckets: [String: [PulseEvent]] = [:]

        for event in events {
            let latIndex = Int((event.coordinate.latitude / gridSize).rounded())
            let lonIndex = Int((event.coordinate.longitude / gridSize).rounded())
            let key = "\(latIndex):\(lonIndex)"
            buckets[key, default: []].append(event)
        }

        return buckets.values.compactMap { bucket in
            let sortedBucket = bucket.sorted {
                if $0.severity.rank != $1.severity.rank {
                    return $0.severity.rank > $1.severity.rank
                }
                return $0.timestamp > $1.timestamp
            }

            guard !sortedBucket.isEmpty else {
                return nil
            }

            let count = Double(sortedBucket.count)
            let averageLatitude = sortedBucket.map(\.coordinate.latitude).reduce(0, +) / count
            let averageLongitude = sortedBucket.map(\.coordinate.longitude).reduce(0, +) / count

            return PulseMapItem(
                id: sortedBucket.map(\.id).joined(separator: "-"),
                coordinate: PulseCoordinate(latitude: averageLatitude, longitude: averageLongitude),
                events: sortedBucket
            )
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.primaryEvent.timestamp > rhs.primaryEvent.timestamp
        }
    }

    private static func clusterGridSize(for region: PulseRegion) -> Double {
        switch region {
        case .world:
            3.0
        case .asia, .northAmerica:
            2.0
        default:
            1.3
        }
    }
}
