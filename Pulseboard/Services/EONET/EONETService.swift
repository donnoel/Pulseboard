import Foundation

actor EONETService: PulseEventProviding {
    let source: PulseSource = .eonet

    private struct CacheEntry {
        let fetchedAt: Date
        let events: [PulseEvent]
    }

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

        guard let url = Self.feedURL(for: timeWindow) else {
            throw EONETServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Pulseboard/1.0 (+https://eonet.gsfc.nasa.gov)", forHTTPHeaderField: "User-Agent")

        let data = try await client.data(for: request)
        let events = try Self.parseEvents(from: data, now: Date.now, timeWindow: timeWindow)
        cache[timeWindow] = CacheEntry(fetchedAt: Date.now, events: events)
        return events
    }

    private static func feedURL(for timeWindow: PulseTimeWindow) -> URL? {
        let days: Int
        switch timeWindow {
        case .hours24:
            days = 1
        case .hours72:
            days = 3
        case .days7:
            days = 7
        }

        var components = URLComponents(string: "https://eonet.gsfc.nasa.gov/api/v3/events")
        components?.queryItems = [
            URLQueryItem(name: "status", value: "open"),
            URLQueryItem(name: "days", value: "\(days)"),
            URLQueryItem(name: "limit", value: "200")
        ]
        return components?.url
    }

    static func parseEvents(from data: Data, now: Date, timeWindow: PulseTimeWindow) throws -> [PulseEvent] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeDate)
        let response = try decoder.decode(EONETEventsResponse.self, from: data)
        let cutoff = now.addingTimeInterval(-timeWindow.timeInterval)

        return response.events
            .compactMap { makeEvent(from: $0, cutoff: cutoff) }
            .sorted(by: sortEvents(lhs:rhs:))
    }

    private static func makeEvent(from event: EONETEvent, cutoff: Date) -> PulseEvent? {
        guard
            let latestGeometry = event.geometry
                .filter({ $0.coordinate != nil })
                .max(by: { $0.date < $1.date }),
            let coordinate = latestGeometry.coordinate,
            latestGeometry.date >= cutoff
        else {
            return nil
        }

        let primaryCategory = event.categories.first
        var metadata: [String: String] = [:]

        if let primaryCategory {
            metadata["Category"] = primaryCategory.title
        }
        metadata["Geometry"] = latestGeometry.type

        if !event.sources.isEmpty {
            metadata["Feed Sources"] = event.sources.map(\.id).joined(separator: ", ")
        }
        if let magnitudeValue = latestGeometry.magnitudeValue {
            if let magnitudeUnit = latestGeometry.magnitudeUnit, !magnitudeUnit.isEmpty {
                metadata["Magnitude"] = Self.formattedMagnitude(value: magnitudeValue, unit: magnitudeUnit)
            } else {
                metadata["Magnitude"] = String(format: "%.1f", magnitudeValue)
            }
        }

        let summary: String
        if let description = event.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            summary = description
        } else if let categoryTitle = primaryCategory?.title {
            summary = "Ongoing \(categoryTitle.lowercased()) event."
        } else {
            summary = "Natural event reported by NASA EONET."
        }

        return PulseEvent(
            id: event.id,
            title: event.title,
            summary: summary,
            category: normalizedCategory(from: event.categories),
            severity: inferSeverity(
                magnitude: latestGeometry.magnitudeValue,
                magnitudeUnit: latestGeometry.magnitudeUnit,
                categoryID: primaryCategory?.id
            ),
            source: .eonet,
            timestamp: latestGeometry.date,
            coordinate: coordinate,
            link: event.link ?? event.sources.first?.url,
            metadata: metadata
        )
    }

    private static func inferSeverity(magnitude: Double?, magnitudeUnit: String?, categoryID: String?) -> PulseSeverity {
        guard let magnitude else {
            if categoryID?.lowercased().contains("severe") == true {
                return .high
            }
            return .unknown
        }

        let unit = magnitudeUnit?.lowercased() ?? ""

        if unit.contains("kts") || unit == "kt" {
            switch magnitude {
            case ..<34:
                return .low
            case ..<64:
                return .moderate
            case ..<96:
                return .high
            default:
                return .severe
            }
        }

        if unit.contains("acres") {
            switch magnitude {
            case ..<500:
                return .low
            case ..<5000:
                return .moderate
            case ..<50000:
                return .high
            default:
                return .severe
            }
        }

        switch magnitude {
        case ..<2:
            return .low
        case ..<5:
            return .moderate
        case ..<8:
            return .high
        default:
            return .severe
        }
    }

    private static func normalizedCategory(from categories: [EONETCategory]) -> PulseCategory {
        if categories.contains(where: { $0.id.lowercased().contains("earthquake") }) {
            return .earthquakes
        }

        return .hazards
    }

    private static func formattedMagnitude(value: Double, unit: String) -> String {
        let formatted = String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", value)
        return "\(formatted) \(unit)"
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
}

enum EONETServiceError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "EONET request URL is invalid."
        }
    }
}

private struct EONETEventsResponse: Decodable {
    let events: [EONETEvent]
}

private struct EONETEvent: Decodable {
    let id: String
    let title: String
    let description: String?
    let link: URL?
    let categories: [EONETCategory]
    let sources: [EONETSource]
    let geometry: [EONETGeometry]
}

private struct EONETCategory: Decodable {
    let id: String
    let title: String
}

private struct EONETSource: Decodable {
    let id: String
    let url: URL?
}

private struct EONETGeometry: Decodable {
    let magnitudeValue: Double?
    let magnitudeUnit: String?
    let date: Date
    let type: String
    let coordinate: PulseCoordinate?

    private enum CodingKeys: String, CodingKey {
        case magnitudeValue
        case magnitudeUnit
        case date
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        magnitudeValue = try container.decodeIfPresent(Double.self, forKey: .magnitudeValue)
        magnitudeUnit = try container.decodeIfPresent(String.self, forKey: .magnitudeUnit)
        date = try container.decode(Date.self, forKey: .date)
        type = try container.decode(String.self, forKey: .type)
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

        if let polygons = try? container.decode([[[[Double]]]].self, forKey: .coordinates),
           let first = polygons.first?.first?.first
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
