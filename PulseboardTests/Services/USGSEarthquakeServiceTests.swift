import Foundation
import XCTest
@testable import Pulseboard

final class USGSEarthquakeServiceTests: XCTestCase {
    func testParseEventsMapsMagnitudeAndCoordinates() throws {
        let data = Data(sampleFeed.utf8)
        let now = Date(timeIntervalSince1970: 1_740_000_000) // 2025-02-15T00:00:00Z

        let events = try USGSEarthquakeService.parseEvents(
            from: data,
            now: now,
            timeWindow: .days7
        )

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.first?.id, "quake-two")
        XCTAssertEqual(events.first?.category, .earthquakes)
        XCTAssertEqual(events.first?.source, .usgs)
        guard let firstEvent = events.first else {
            XCTFail("Expected first event")
            return
        }
        XCTAssertEqual(firstEvent.coordinate.latitude, 63.2, accuracy: 0.001)
        XCTAssertEqual(firstEvent.coordinate.longitude, -147.3, accuracy: 0.001)
        XCTAssertEqual(events.first?.severity, .high)
    }

    func testParseEventsAppliesTimeWindowCutoff() throws {
        let data = Data(sampleFeed.utf8)
        let now = Date(timeIntervalSince1970: 1_740_000_000) // 2025-02-15T00:00:00Z

        let events = try USGSEarthquakeService.parseEvents(
            from: data,
            now: now,
            timeWindow: .hours24
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.id, "quake-two")
    }

    private let sampleFeed = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "id": "quake-one",
          "properties": {
            "mag": 4.6,
            "place": "24 km SW of Testville",
            "time": 1739822000000,
            "alert": "yellow",
            "title": "M 4.6 - 24 km SW of Testville",
            "url": "https://earthquake.usgs.gov/test/quake-one"
          },
          "geometry": { "type": "Point", "coordinates": [-121.9, 36.4, 11.7] }
        },
        {
          "id": "quake-two",
          "properties": {
            "mag": 6.3,
            "place": "Northern Range",
            "time": 1739996400000,
            "alert": "orange",
            "title": "M 6.3 - Northern Range",
            "url": "https://earthquake.usgs.gov/test/quake-two"
          },
          "geometry": { "type": "Point", "coordinates": [-147.3, 63.2, 27.1] }
        }
      ]
    }
    """
}
