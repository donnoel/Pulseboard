import Foundation
import XCTest
@testable import Pulseboard

final class GDACSServiceTests: XCTestCase {
    func testParseEventsNormalizesCategorySeverityCoordinatesAndMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_774_000_000) // 2026-03-20T12:26:40Z
        let data = Data(sampleResponse.utf8)

        let events = try GDACSService.parseEvents(from: data, now: now, timeWindow: .days7)

        XCTAssertEqual(events.count, 2)

        guard let first = events.first else {
            XCTFail("Expected at least one event")
            return
        }

        XCTAssertEqual(first.id, "TC-2001-8")
        XCTAssertEqual(first.category, .hazards)
        XCTAssertEqual(first.severity, .high)
        XCTAssertEqual(first.source, .gdacs)
        XCTAssertEqual(first.coordinate.latitude, -13.4, accuracy: 0.001)
        XCTAssertEqual(first.coordinate.longitude, 143.0, accuracy: 0.001)
        XCTAssertEqual(first.link?.absoluteString, "https://www.gdacs.org/report.aspx?eventid=2001&episodeid=8&eventtype=TC")
        XCTAssertEqual(first.metadata["Alert"], "Orange")
        XCTAssertEqual(first.metadata["Type"], "TC")
    }

    func testParseEventsAppliesTimeWindowCutoff() throws {
        let now = Date(timeIntervalSince1970: 1_774_000_000)
        let data = Data(sampleResponse.utf8)

        let events = try GDACSService.parseEvents(from: data, now: now, timeWindow: .hours24)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.id, "TC-2001-8")
        XCTAssertFalse(events.contains(where: { $0.id == "EQ-1001-1" }))
    }

    private let sampleResponse = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [143.0, -13.4]
          },
          "properties": {
            "eventtype": "TC",
            "eventid": 2001,
            "episodeid": 8,
            "eventname": "",
            "name": "Tropical Cyclone Example",
            "description": "Cyclone moving across open waters.",
            "htmldescription": "Orange cyclone advisory.",
            "alertlevel": "Orange",
            "alertscore": 2,
            "country": "Australia",
            "source": "JTWC",
            "fromdate": "2026-03-20T02:00:00",
            "todate": "2026-03-20T11:00:00",
            "datemodified": "2026-03-20T12:00:00",
            "url": {
              "report": "https://www.gdacs.org/report.aspx?eventid=2001&episodeid=8&eventtype=TC",
              "details": "https://www.gdacs.org/gdacsapi/api/events/geteventdata?eventtype=TC&eventid=2001"
            },
            "severitydata": {
              "severitytext": "Hurricane/Typhoon"
            }
          }
        },
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [-118.2, 34.1]
          },
          "properties": {
            "eventtype": "EQ",
            "eventid": 1001,
            "episodeid": 1,
            "eventname": "",
            "name": "Earthquake Example",
            "description": "Earthquake in coastal region.",
            "htmldescription": "",
            "alertlevel": "Green",
            "alertscore": 1,
            "country": "United States",
            "source": "NEIC",
            "fromdate": "2026-03-18T01:00:00",
            "todate": "2026-03-18T01:00:00",
            "datemodified": "2026-03-18T02:00:00",
            "url": {
              "report": "https://www.gdacs.org/report.aspx?eventid=1001&episodeid=1&eventtype=EQ",
              "details": "https://www.gdacs.org/gdacsapi/api/events/geteventdata?eventtype=EQ&eventid=1001"
            },
            "severitydata": {
              "severitytext": "Magnitude 5.1"
            }
          }
        },
        {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [20.0]
          },
          "properties": {
            "eventtype": "FL",
            "eventid": 3001,
            "episodeid": 2,
            "eventname": "",
            "name": "Invalid coordinate sample",
            "description": "",
            "htmldescription": "",
            "alertlevel": "Yellow",
            "alertscore": 2,
            "fromdate": "2026-03-20T03:00:00",
            "todate": "2026-03-20T05:00:00",
            "datemodified": "2026-03-20T05:00:00",
            "url": {
              "report": "https://www.gdacs.org/report.aspx?eventid=3001&episodeid=2&eventtype=FL"
            }
          }
        }
      ]
    }
    """
}
