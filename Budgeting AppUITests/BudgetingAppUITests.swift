import XCTest

final class BudgetingAppUITests: XCTestCase {
    @MainActor
    func testLaunchAndOpenWallets() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let walletsTab = app.tabBars.buttons["Wallets"]
        XCTAssertTrue(walletsTab.waitForExistence(timeout: 10))
        walletsTab.tap()
        XCTAssertTrue(app.navigationBars["Wallets"].waitForExistence(timeout: 5))
    }
}
