import XCTest

final class PulseboardUITests: XCTestCase {
    func testLaunchShowsPulseMapShell() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["app.shell"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["pulse.map.home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Pulse"].exists)
    }
}
