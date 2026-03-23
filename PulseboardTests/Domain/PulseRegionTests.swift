import XCTest
@testable import Pulseboard

final class PulseRegionTests: XCTestCase {
    func testNorthAmericaContainsSanFrancisco() {
        let sanFrancisco = PulseCoordinate(latitude: 37.7749, longitude: -122.4194)
        XCTAssertTrue(PulseRegion.northAmerica.contains(sanFrancisco))
    }

    func testEuropeDoesNotContainTokyo() {
        let tokyo = PulseCoordinate(latitude: 35.6764, longitude: 139.65)
        XCTAssertFalse(PulseRegion.europe.contains(tokyo))
    }

    func testWorldContainsAnyCoordinate() {
        let randomCoordinate = PulseCoordinate(latitude: -12.42, longitude: 130.84)
        XCTAssertTrue(PulseRegion.world.contains(randomCoordinate))
    }
}
