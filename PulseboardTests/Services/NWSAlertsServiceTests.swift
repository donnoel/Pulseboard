import Foundation
import XCTest
@testable import Pulseboard

final class NWSAlertsServiceTests: XCTestCase {
    func testParseEventsNormalizesActiveAlertGeometrySeverityAndMetadata() throws {
        let now = try XCTUnwrap(Self.date("2026-05-18T00:00:00Z"))
        let data = Data(sampleResponse.utf8)

        let events = try NWSAlertsService.parseEvents(from: data, now: now, timeWindow: .hours24)

        XCTAssertEqual(events.count, 2)

        guard let first = events.first else {
            XCTFail("Expected at least one event")
            return
        }

        XCTAssertEqual(first.id, "urn:oid:severe-thunderstorm")
        XCTAssertEqual(first.title, "Severe Thunderstorm Warning")
        XCTAssertEqual(first.category, .alerts)
        XCTAssertEqual(first.severity, .severe)
        XCTAssertEqual(first.source, .nws)
        XCTAssertEqual(first.coordinate.latitude, 42.865, accuracy: 0.001)
        XCTAssertEqual(first.coordinate.longitude, -96.33, accuracy: 0.001)
        XCTAssertEqual(first.link?.absoluteString, "https://api.weather.gov/alerts/urn:oid:severe-thunderstorm")
        XCTAssertEqual(first.metadata["Provider"], "National Weather Service")
        XCTAssertEqual(first.metadata["Area"], "Plymouth, IA; Sioux, IA")
        XCTAssertEqual(first.metadata["NWS Severity"], "Severe")
        XCTAssertEqual(first.metadata["Urgency"], "Immediate")
        XCTAssertEqual(first.metadata["Certainty"], "Observed")
        XCTAssertEqual(first.metadata["Office"], "NWS Sioux Falls SD")
    }

    func testParseEventsAppliesTimeWindowAndSkipsAlertsWithoutUsableCoordinates() throws {
        let now = try XCTUnwrap(Self.date("2026-05-18T00:00:00Z"))
        let data = Data(sampleResponse.utf8)

        let events = try NWSAlertsService.parseEvents(from: data, now: now, timeWindow: .hours24)

        XCTAssertFalse(events.contains(where: { $0.id == "urn:oid:older-flood-watch" }))
        XCTAssertFalse(events.contains(where: { $0.id == "urn:oid:no-geometry" }))
        XCTAssertFalse(events.contains(where: { $0.id == "urn:oid:invalid-coordinate" }))
    }

    func testParseEventsUsesConservativeSeverityFallbackForLikelyImmediateAlerts() throws {
        let now = try XCTUnwrap(Self.date("2026-05-18T00:00:00Z"))
        let data = Data(sampleResponse.utf8)

        let events = try NWSAlertsService.parseEvents(from: data, now: now, timeWindow: .hours24)
        let fallback = try XCTUnwrap(events.first { $0.id == "urn:oid:unknown-immediate" })

        XCTAssertEqual(fallback.severity, .moderate)
        XCTAssertEqual(fallback.coordinate.latitude, 39.5, accuracy: 0.001)
        XCTAssertEqual(fallback.coordinate.longitude, -104.8, accuracy: 0.001)
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private let sampleResponse = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "id": "https://api.weather.gov/alerts/urn:oid:severe-thunderstorm",
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [
                [-96.51, 42.69],
                [-96.59, 42.81],
                [-96.58, 42.84],
                [-96.55, 42.84],
                [-96.55, 42.88],
                [-96.22, 43.04],
                [-96.07, 42.76],
                [-96.51, 42.69]
              ]
            ]
          },
          "properties": {
            "id": "urn:oid:severe-thunderstorm",
            "areaDesc": "Plymouth, IA; Sioux, IA",
            "sent": "2026-05-17T18:33:00-05:00",
            "effective": "2026-05-17T18:33:00-05:00",
            "onset": "2026-05-17T18:33:00-05:00",
            "expires": "2026-05-17T19:30:00-05:00",
            "ends": "2026-05-17T19:30:00-05:00",
            "severity": "Severe",
            "certainty": "Observed",
            "urgency": "Immediate",
            "event": "Severe Thunderstorm Warning",
            "senderName": "NWS Sioux Falls SD",
            "headline": "Severe Thunderstorm Warning issued May 17 at 6:33PM CDT",
            "description": "A severe thunderstorm was located near the county line.",
            "instruction": "Move to an interior room.",
            "web": "https://api.weather.gov/alerts/urn:oid:severe-thunderstorm"
          }
        },
        {
          "id": "https://api.weather.gov/alerts/urn:oid:unknown-immediate",
          "geometry": {
            "type": "Point",
            "coordinates": [-104.8, 39.5]
          },
          "properties": {
            "id": "urn:oid:unknown-immediate",
            "areaDesc": "Denver, CO",
            "sent": "2026-05-17T20:00:00Z",
            "effective": "2026-05-17T20:00:00Z",
            "severity": "Unknown",
            "certainty": "Likely",
            "urgency": "Expected",
            "event": "Special Weather Statement",
            "senderName": "NWS Denver CO",
            "headline": "Special Weather Statement",
            "description": "Gusty outflow winds are expected."
          }
        },
        {
          "id": "https://api.weather.gov/alerts/urn:oid:older-flood-watch",
          "geometry": {
            "type": "Point",
            "coordinates": [-90.1, 35.1]
          },
          "properties": {
            "id": "urn:oid:older-flood-watch",
            "areaDesc": "Shelby, TN",
            "sent": "2026-05-15T00:00:00Z",
            "effective": "2026-05-15T00:00:00Z",
            "severity": "Moderate",
            "certainty": "Possible",
            "urgency": "Future",
            "event": "Flood Watch",
            "description": "Older alert outside the selected window."
          }
        },
        {
          "id": "https://api.weather.gov/alerts/urn:oid:no-geometry",
          "geometry": null,
          "properties": {
            "id": "urn:oid:no-geometry",
            "areaDesc": "Statewide",
            "sent": "2026-05-17T20:00:00Z",
            "effective": "2026-05-17T20:00:00Z",
            "severity": "Minor",
            "certainty": "Likely",
            "urgency": "Expected",
            "event": "Air Quality Alert",
            "description": "Alert without a mappable geometry."
          }
        },
        {
          "id": "https://api.weather.gov/alerts/urn:oid:invalid-coordinate",
          "geometry": {
            "type": "Point",
            "coordinates": [-190.0, 95.0]
          },
          "properties": {
            "id": "urn:oid:invalid-coordinate",
            "areaDesc": "Invalid",
            "sent": "2026-05-17T20:00:00Z",
            "effective": "2026-05-17T20:00:00Z",
            "severity": "Minor",
            "certainty": "Likely",
            "urgency": "Expected",
            "event": "Invalid Coordinate Alert",
            "description": "Invalid coordinates should not be mapped."
          }
        }
      ]
    }
    """
}
