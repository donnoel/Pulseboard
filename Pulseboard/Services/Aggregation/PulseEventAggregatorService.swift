import Foundation

struct PulseSourceFailure: Sendable, Hashable {
    let source: PulseSource
    let message: String
}

struct PulseEventAggregationResult: Sendable {
    let events: [PulseEvent]
    let failures: [PulseSourceFailure]
    let successfulSourceCount: Int

    var hasFailures: Bool {
        !failures.isEmpty
    }

    var hasSuccessfulSources: Bool {
        successfulSourceCount > 0
    }
}

enum PulseRuntimeSources {
    static let activeSources: [PulseSource] = [.usgs, .eonet]
}

actor PulseEventAggregatorService {
    private enum SourceFetchOutcome: Sendable {
        case success(source: PulseSource, events: [PulseEvent])
        case failure(PulseSourceFailure)
    }

    private let providers: [any PulseEventProviding]

    init(providers: [any PulseEventProviding] = [USGSEarthquakeService(), EONETService()]) {
        self.providers = providers
    }

    func fetchEvents(in timeWindow: PulseTimeWindow) async -> PulseEventAggregationResult {
        await withTaskGroup(of: SourceFetchOutcome.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let events = try await provider.fetchEvents(in: timeWindow)
                        return .success(source: provider.source, events: events)
                    } catch {
                        return .failure(PulseSourceFailure(source: provider.source, message: error.localizedDescription))
                    }
                }
            }

            var collectedEvents: [PulseEvent] = []
            var failures: [PulseSourceFailure] = []
            var successfulSourceCount = 0

            for await outcome in group {
                switch outcome {
                case let .success(source, events):
                    successfulSourceCount += 1
                    // Prefix source into IDs to prevent collisions across feeds.
                    collectedEvents.append(contentsOf: events.map { event in
                        PulseEvent(
                            id: "\(source.rawValue)-\(event.id)",
                            title: event.title,
                            summary: event.summary,
                            category: event.category,
                            severity: event.severity,
                            source: event.source,
                            timestamp: event.timestamp,
                            coordinate: event.coordinate,
                            link: event.link,
                            metadata: event.metadata
                        )
                    })
                case let .failure(failure):
                    failures.append(failure)
                }
            }

            let sorted = collectedEvents.sorted { lhs, rhs in
                if lhs.severity.rank != rhs.severity.rank {
                    return lhs.severity.rank > rhs.severity.rank
                }
                return lhs.timestamp > rhs.timestamp
            }

            return PulseEventAggregationResult(
                events: sorted,
                failures: failures.sorted { $0.source.rawValue < $1.source.rawValue },
                successfulSourceCount: successfulSourceCount
            )
        }
    }
}
