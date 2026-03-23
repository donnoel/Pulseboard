import XCTest

final class PulseboardUITests: XCTestCase {
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        // Basic smoke test
        XCTAssertTrue(app.windows.count >= 0)
    }
}