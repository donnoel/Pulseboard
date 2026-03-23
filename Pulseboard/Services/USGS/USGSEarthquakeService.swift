import Foundation

actor USGSEarthquakeService: PulseEventProviding {
    let source: PulseSource = .usgs

    private struct CacheEntry {
        let fetchedAt: Date
        let events: [PulseEvent]
    }

    private let client: HTTPClient
    private let cacheTTL: TimeInterval
    private var cache: [PulseTimeWindow: CacheEntry] = [:]

    init(client: HTTPClient = HTTPClient(), cacheTTL: TimeInterval = 180) {
        self.client = client
        self.cacheTTL = cacheTTL
    }

    func fetchEvents(in timeWindow: PulseTimeWindow) async throws -> [PulseEvent] {
        if let cached = cache[timeWindow], Date.now.timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.events
        }

        var request = URLRequest(url: Self.feedURL(for: timeWindow))
        request.timeoutInterval = 20
        request.setValue("application/geo+json, application/json", forHTTPHeaderField: "Accept")
        request.setValue("Pulseboard/1.0 (+https://earthquake.usgs.gov)", forHTTPHeaderField: "User-Agent")

        let data = try await client.data(for: request)
        let events = try Self.parseEvents(from: data, now: Date.now, timeWindow: timeWindow)
        cache[timeWindow] = CacheEntry(fetchedAt: Date.now, events: events)
        return events
    }

    private static func feedURL(for timeWindow: PulseTimeWindow) -> URL {
        let base = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary"
        return URL(string: "\(base)/\(timeWindow.usgsFeedPath)") ?? URL(string: "\(base)/all_day.geojson")!
    }

    static func parseEvents(from data: Data, now: Date, timeWindow: PulseTimeWindow) throws -> [PulseEvent] {
        let decoder = JSONDecoder()
        let response = try decoder.decode(USGSFeedResponse.self, from: data)
        let cutoff = now.addingTimeInterval(-timeWindow.timeInterval)

        return response.features
            .compactMap(Self.makeEvent(from:))
            .filter { $0.timestamp >= cutoff }
            .sorted(by: Self.sortEvents(lhs:rhs:))
    }

    private static func makeEvent(from feature: USGSFeature) -> PulseEvent? {
        guard
            feature.geometry.coordinates.count >= 2,
            let timestampMilliseconds = feature.properties.time
        else {
            return nil
        }

        let longitude = feature.geometry.coordinates[0]
        let latitude = feature.geometry.coordinates[1]
        let depth = feature.geometry.coordinates.count > 2 ? feature.geometry.coordinates[2] : nil
        let magnitude = feature.properties.mag
        let eventTime = Date(timeIntervalSince1970: TimeInterval(timestampMilliseconds) / 1000)

        var metadata: [String: String] = [:]
        if let magnitude {
            metadata["Magnitude"] = String(format: "%.1f", magnitude)
        }
        if let depth {
            metadata["Depth"] = String(format: "%.0f km", depth)
        }
        if let place = feature.properties.place {
            metadata["Location"] = place
        }

        return PulseEvent(
            id: feature.id,
            title: feature.properties.title ?? "Earthquake",
            summary: feature.properties.place ?? "Location unavailable",
            category: .earthquakes,
            severity: PulseSeverity.fromMagnitude(magnitude, alertLevel: feature.properties.alert),
            source: .usgs,
            timestamp: eventTime,
            coordinate: PulseCoordinate(latitude: latitude, longitude: longitude),
            link: feature.properties.url,
            metadata: metadata
        )
    }

    private static func sortEvents(lhs: PulseEvent, rhs: PulseEvent) -> Bool {
        if lhs.severity.rank != rhs.severity.rank {
            return lhs.severity.rank > rhs.severity.rank
        }

        return lhs.timestamp > rhs.timestamp
    }
}

private struct USGSFeedResponse: Decodable {
    let features: [USGSFeature]
}

private struct USGSFeature: Decodable {
    let id: String
    let properties: USGSFeatureProperties
    let geometry: USGSGeometry
}

private struct USGSFeatureProperties: Decodable {
    let mag: Double?
    let place: String?
    let time: Int64?
    let alert: String?
    let title: String?
    let url: URL?
}

private struct USGSGeometry: Decodable {
    let coordinates: [Double]
}
