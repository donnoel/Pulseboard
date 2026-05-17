import Foundation

actor NWSAlertsService: PulseEventProviding {
    let source: PulseSource = .nws

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

        guard let url = Self.feedURL else {
            throw NWSAlertsServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/geo+json, application/json", forHTTPHeaderField: "Accept")
        request.setValue("Pulseboard/1.0 (+https://www.weather.gov)", forHTTPHeaderField: "User-Agent")

        let data = try await client.data(for: request)
        let events = try Self.parseEvents(from: data, now: Date.now, timeWindow: timeWindow)
        cache[timeWindow] = CacheEntry(fetchedAt: Date.now, events: events)
        return events
    }

    private static var feedURL: URL? {
        var components = URLComponents(string: "https://api.weather.gov/alerts/active")
        components?.queryItems = [
            URLQueryItem(name: "status", value: "actual"),
            URLQueryItem(name: "message_type", value: "alert")
        ]
        return components?.url
    }

    static func parseEvents(from data: Data, now: Date, timeWindow: PulseTimeWindow) throws -> [PulseEvent] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeDate)
        let response = try decoder.decode(NWSAlertResponse.self, from: data)
        let cutoff = now.addingTimeInterval(-timeWindow.timeInterval)

        return response.features
            .compactMap(Self.makeEvent(from:))
            .filter { $0.timestamp >= cutoff }
            .sorted(by: Self.sortEvents(lhs:rhs:))
    }

    private static func makeEvent(from feature: NWSAlertFeature) -> PulseEvent? {
        guard
            let coordinate = feature.geometry?.coordinate,
            let timestamp = feature.properties.onset
                ?? feature.properties.effective
                ?? feature.properties.sent
        else {
            return nil
        }

        let title = nonEmpty(feature.properties.event)
            ?? nonEmpty(feature.properties.headline)
            ?? "NWS Alert"

        let summary = nonEmpty(feature.properties.description)
            ?? nonEmpty(feature.properties.headline)
            ?? nonEmpty(feature.properties.areaDescription)
            ?? "Active alert from the National Weather Service."

        var metadata: [String: String] = [:]
        metadata["Provider"] = "National Weather Service"
        if let area = nonEmpty(feature.properties.areaDescription) {
            metadata["Area"] = area
        }
        if let severity = nonEmpty(feature.properties.severity) {
            metadata["NWS Severity"] = severity
        }
        if let urgency = nonEmpty(feature.properties.urgency) {
            metadata["Urgency"] = urgency
        }
        if let certainty = nonEmpty(feature.properties.certainty) {
            metadata["Certainty"] = certainty
        }
        if let senderName = nonEmpty(feature.properties.senderName) {
            metadata["Office"] = senderName
        }

        return PulseEvent(
            id: feature.properties.id ?? feature.id,
            title: title,
            summary: summary,
            category: .alerts,
            severity: normalizedSeverity(
                severity: feature.properties.severity,
                urgency: feature.properties.urgency,
                certainty: feature.properties.certainty
            ),
            source: .nws,
            timestamp: timestamp,
            coordinate: coordinate,
            link: feature.properties.web,
            metadata: metadata
        )
    }

    private static func normalizedSeverity(
        severity: String?,
        urgency: String?,
        certainty: String?
    ) -> PulseSeverity {
        switch severity?.lowercased() {
        case "extreme", "severe":
            return .severe
        case "moderate":
            return .high
        case "minor":
            return .moderate
        default:
            break
        }

        let urgent = urgency?.lowercased()
        let likely = certainty?.lowercased()
        if (urgent == "immediate" || urgent == "expected")
            && (likely == "observed" || likely == "likely")
        {
            return .moderate
        }

        return .unknown
    }

    private static func sortEvents(lhs: PulseEvent, rhs: PulseEvent) -> Bool {
        if lhs.severity.rank != rhs.severity.rank {
            return lhs.severity.rank > rhs.severity.rank
        }
        return lhs.timestamp > rhs.timestamp
    }

    private static func decodeDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        if let parsed = fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value) {
            return parsed
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(value)")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum NWSAlertsServiceError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "NWS request URL is invalid."
        }
    }
}

private struct NWSAlertResponse: Decodable {
    let features: [NWSAlertFeature]
}

private struct NWSAlertFeature: Decodable {
    let id: String
    let geometry: NWSGeometry?
    let properties: NWSAlertProperties
}

private struct NWSAlertProperties: Decodable {
    let id: String?
    let areaDescription: String?
    let sent: Date?
    let effective: Date?
    let onset: Date?
    let severity: String?
    let certainty: String?
    let urgency: String?
    let event: String?
    let senderName: String?
    let headline: String?
    let description: String?
    let web: URL?

    private enum CodingKeys: String, CodingKey {
        case id
        case areaDescription = "areaDesc"
        case sent
        case effective
        case onset
        case severity
        case certainty
        case urgency
        case event
        case senderName
        case headline
        case description
        case web
    }
}

private struct NWSGeometry: Decodable {
    let coordinate: PulseCoordinate?

    private enum CodingKeys: String, CodingKey {
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coordinate = Self.decodeCoordinate(from: container)
    }

    private static func decodeCoordinate(from container: KeyedDecodingContainer<CodingKeys>) -> PulseCoordinate? {
        if let pair = try? container.decode([Double].self, forKey: .coordinates) {
            return decodePair(pair)
        }

        if let pairs = try? container.decode([[Double]].self, forKey: .coordinates) {
            return representativeCoordinate(from: pairs)
        }

        if let rings = try? container.decode([[[Double]]].self, forKey: .coordinates) {
            return representativeCoordinate(from: rings.flatMap { $0 })
        }

        if let polygons = try? container.decode([[[[Double]]]].self, forKey: .coordinates) {
            return representativeCoordinate(from: polygons.flatMap { $0 }.flatMap { $0 })
        }

        return nil
    }

    private static func representativeCoordinate(from pairs: [[Double]]) -> PulseCoordinate? {
        let coordinates = pairs.compactMap(decodePair)
        guard
            let minLatitude = coordinates.map(\.latitude).min(),
            let maxLatitude = coordinates.map(\.latitude).max(),
            let minLongitude = coordinates.map(\.longitude).min(),
            let maxLongitude = coordinates.map(\.longitude).max()
        else {
            return nil
        }

        return PulseCoordinate(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
    }

    private static func decodePair(_ pair: [Double]) -> PulseCoordinate? {
        guard pair.count >= 2 else {
            return nil
        }

        let longitude = pair[0]
        let latitude = pair[1]
        guard (-90 ... 90).contains(latitude), (-180 ... 180).contains(longitude) else {
            return nil
        }

        return PulseCoordinate(latitude: latitude, longitude: longitude)
    }
}
