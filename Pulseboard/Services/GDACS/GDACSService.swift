import Foundation

actor GDACSService: PulseEventProviding {
    let source: PulseSource = .gdacs

    private struct CacheEntry {
        let fetchedAt: Date
        let events: [PulseEvent]
    }

    private static let feedURL = URL(string: "https://www.gdacs.org/gdacsapi/api/Events/geteventlist/EVENTS4APP")!

    private let client: HTTPClient
    private let cacheTTL: TimeInterval
    private var cache: [PulseTimeWindow: CacheEntry] = [:]

    init(client: HTTPClient = HTTPClient(), cacheTTL: TimeInterval = 300) {
        self.client = client
        self.cacheTTL = cacheTTL
    }

    func fetchEvents(in timeWindow: PulseTimeWindow) async throws -> [PulseEvent] {
        if let cached = cache[timeWindow], Date.now.timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.events
        }

        var request = URLRequest(url: Self.feedURL)
        request.timeoutInterval = 20
        request.setValue("application/geo+json, application/json", forHTTPHeaderField: "Accept")
        request.setValue("Pulseboard/1.0 (+https://www.gdacs.org)", forHTTPHeaderField: "User-Agent")

        let data = try await client.data(for: request)
        let events = try Self.parseEvents(from: data, now: Date.now, timeWindow: timeWindow)
        cache[timeWindow] = CacheEntry(fetchedAt: Date.now, events: events)
        return events
    }

    static func parseEvents(from data: Data, now: Date, timeWindow: PulseTimeWindow) throws -> [PulseEvent] {
        let decoder = JSONDecoder()
        let response = try decoder.decode(GDACSFeedResponse.self, from: data)
        let cutoff = now.addingTimeInterval(-timeWindow.timeInterval)

        return response.features
            .compactMap(Self.makeEvent(from:))
            .filter { $0.timestamp >= cutoff }
            .sorted(by: Self.sortEvents(lhs:rhs:))
    }

    private static func makeEvent(from feature: GDACSFeature) -> PulseEvent? {
        guard let coordinate = feature.geometry.coordinate else {
            return nil
        }

        let timestamp = parsedDate(feature.properties.dateModified)
            ?? parsedDate(feature.properties.toDate)
            ?? parsedDate(feature.properties.fromDate)
            ?? Date.distantPast
        guard timestamp != .distantPast else {
            return nil
        }

        let eventType = feature.properties.eventType
        let eventID = String(feature.properties.eventID)
        let episodeID = String(feature.properties.episodeID)
        let id = "\(eventType)-\(eventID)-\(episodeID)"

        let title = firstNonEmpty(
            feature.properties.name,
            feature.properties.eventName,
            feature.properties.description
        ) ?? "GDACS Event"

        let summary = firstNonEmpty(
            feature.properties.description,
            feature.properties.htmlDescription,
            feature.properties.name
        ) ?? "Natural hazard reported by GDACS."

        var metadata: [String: String] = [:]
        if let alert = nonEmpty(feature.properties.alertLevel) {
            metadata["Alert"] = alert
        }
        metadata["Type"] = eventType
        if let country = nonEmpty(feature.properties.country) {
            metadata["Country"] = country
        }
        if let source = nonEmpty(feature.properties.source) {
            metadata["Feed Source"] = source
        }
        if let severityText = nonEmpty(feature.properties.severityData?.severityText) {
            metadata["Severity"] = severityText
        }

        return PulseEvent(
            id: id,
            title: title,
            summary: summary,
            category: normalizedCategory(for: eventType),
            severity: normalizedSeverity(
                alertLevel: feature.properties.alertLevel,
                alertScore: feature.properties.alertScore
            ),
            source: .gdacs,
            timestamp: timestamp,
            coordinate: coordinate,
            link: feature.properties.urls.report ?? feature.properties.urls.details,
            metadata: metadata
        )
    }

    private static func parsedDate(_ value: String?) -> Date? {
        guard let value = nonEmpty(value) else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fractionalFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        standardFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let basicFormatter = DateFormatter()
        basicFormatter.calendar = Calendar(identifier: .iso8601)
        basicFormatter.locale = Locale(identifier: "en_US_POSIX")
        basicFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        if let parsed = fractionalFormatter.date(from: value)
            ?? standardFormatter.date(from: value)
            ?? basicFormatter.date(from: value)
        {
            return parsed
        }

        return nil
    }

    private static func normalizedCategory(for eventType: String) -> PulseCategory {
        switch eventType.uppercased() {
        case "EQ":
            return .earthquakes
        default:
            return .hazards
        }
    }

    private static func normalizedSeverity(alertLevel: String?, alertScore: Double?) -> PulseSeverity {
        switch alertLevel?.lowercased() {
        case "red":
            return .severe
        case "orange":
            return .high
        case "yellow":
            return .moderate
        case "green":
            return .low
        default:
            break
        }

        guard let alertScore else {
            return .unknown
        }

        switch alertScore {
        case ..<1:
            return .low
        case ..<2:
            return .moderate
        case ..<3:
            return .high
        default:
            return .severe
        }
    }

    private static func sortEvents(lhs: PulseEvent, rhs: PulseEvent) -> Bool {
        if lhs.severity.rank != rhs.severity.rank {
            return lhs.severity.rank > rhs.severity.rank
        }
        return lhs.timestamp > rhs.timestamp
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values.compactMap(nonEmpty).first
    }
}

private struct GDACSFeedResponse: Decodable {
    let features: [GDACSFeature]
}

private struct GDACSFeature: Decodable {
    let geometry: GDACSGeometry
    let properties: GDACSProperties
}

private struct GDACSGeometry: Decodable {
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

        if let pairs = try? container.decode([[Double]].self, forKey: .coordinates), let first = pairs.first {
            return decodePair(first)
        }

        if let rings = try? container.decode([[[Double]]].self, forKey: .coordinates),
           let first = rings.first?.first
        {
            return decodePair(first)
        }

        return nil
    }

    private static func decodePair(_ pair: [Double]) -> PulseCoordinate? {
        guard pair.count >= 2 else {
            return nil
        }
        return PulseCoordinate(latitude: pair[1], longitude: pair[0])
    }
}

private struct GDACSProperties: Decodable {
    let eventType: String
    let eventID: Int
    let episodeID: Int
    let eventName: String?
    let name: String?
    let description: String?
    let htmlDescription: String?
    let alertLevel: String?
    let alertScore: Double?
    let country: String?
    let source: String?
    let fromDate: String?
    let toDate: String?
    let dateModified: String?
    let severityData: GDACSSeverityData?
    let urls: GDACSURLs

    private enum CodingKeys: String, CodingKey {
        case eventType = "eventtype"
        case eventID = "eventid"
        case episodeID = "episodeid"
        case eventName = "eventname"
        case name
        case description
        case htmlDescription = "htmldescription"
        case alertLevel = "alertlevel"
        case alertScore = "alertscore"
        case country
        case source
        case fromDate = "fromdate"
        case toDate = "todate"
        case dateModified = "datemodified"
        case severityData = "severitydata"
        case urls = "url"
    }
}

private struct GDACSSeverityData: Decodable {
    let severityText: String?

    private enum CodingKeys: String, CodingKey {
        case severityText = "severitytext"
    }
}

private struct GDACSURLs: Decodable {
    let report: URL?
    let details: URL?
}
