import Foundation
import XCTest
@testable import Pulseboard

final class EONETServiceTests: XCTestCase {
    func testParseEventsNormalizesCategorySeverityAndCoordinates() throws {
        let now = Date(timeIntervalSince1970: 1_774_000_000) // 2026-03-20T12:26:40Z
        let data = Data(sampleResponse.utf8)

        let events = try EONETService.parseEvents(from: data, now: now, timeWindow: .hours24)

        XCTAssertEqual(events.count, 2)

        guard let first = events.first else {
            XCTFail("Expected at least one event")
            return
        }

        XCTAssertEqual(first.id, "EONET_100")
        XCTAssertEqual(first.category, .hazards)
        XCTAssertEqual(first.severity, .severe)
        XCTAssertEqual(first.coordinate.latitude, -13.4, accuracy: 0.001)
        XCTAssertEqual(first.coordinate.longitude, 143.0, accuracy: 0.001)
        XCTAssertEqual(first.source, .eonet)
        XCTAssertEqual(first.metadata["Category"], "Severe Storms")
    }

    func testParseEventsAppliesTimeWindowCutoff() throws {
        let now = Date(timeIntervalSince1970: 1_774_000_000)
        let data = Data(sampleResponse.utf8)

        let events = try EONETService.parseEvents(from: data, now: now, timeWindow: .hours24)

        XCTAssertEqual(events.count, 2)
        XCTAssertFalse(events.contains(where: { $0.id == "EONET_102" }))
    }

    private let sampleResponse = """
    {
      "events": [
        {
          "id": "EONET_100",
          "title": "Tropical Cyclone Test",
          "description": null,
          "link": "https://eonet.gsfc.nasa.gov/api/v3/events/EONET_100",
          "categories": [
            { "id": "severeStorms", "title": "Severe Storms" }
          ],
          "sources": [
            { "id": "JTWC", "url": "https://example.com/jtwc" }
          ],
          "geometry": [
            {
              "magnitudeValue": 85.0,
              "magnitudeUnit": "kts",
              "date": "2026-03-19T12:00:00Z",
              "type": "Point",
              "coordinates": [145.4, -13.6]
            },
            {
              "magnitudeValue": 105.0,
              "magnitudeUnit": "kts",
              "date": "2026-03-20T06:00:00Z",
              "type": "Point",
              "coordinates": [143.0, -13.4]
            }
          ]
        },
        {
          "id": "EONET_101",
          "title": "Regional Earthquake",
          "description": "Shaking reported across the region.",
          "link": "https://eonet.gsfc.nasa.gov/api/v3/events/EONET_101",
          "categories": [
            { "id": "earthquakes", "title": "Earthquakes" }
          ],
          "sources": [
            { "id": "EMSC", "url": "https://example.com/emsc" }
          ],
          "geometry": [
            {
              "magnitudeValue": 5.2,
              "magnitudeUnit": "Mw",
              "date": "2026-03-20T10:00:00Z",
              "type": "Point",
              "coordinates": [-121.9, 36.4]
            }
          ]
        },
        {
          "id": "EONET_102",
          "title": "Older Flood Event",
          "description": null,
          "link": "https://eonet.gsfc.nasa.gov/api/v3/events/EONET_102",
          "categories": [
            { "id": "floods", "title": "Floods" }
          ],
          "sources": [
            { "id": "DFO", "url": "https://example.com/dfo" }
          ],
          "geometry": [
            {
              "date": "2026-03-17T05:00:00Z",
              "type": "Point",
              "coordinates": [12.2, 41.9]
            }
          ]
        }
      ]
    }
    """
}
