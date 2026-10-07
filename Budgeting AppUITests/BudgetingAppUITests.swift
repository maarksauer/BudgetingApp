import XCTest
import Foundation

final class BudgetingAppUITests: XCTestCase {
    @MainActor
    func testLaunchDashboardAndAddExpenseFromWallets() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Spent this month"].exists)

        let walletsTab = app.tabBars.buttons["Wallets"]
        XCTAssertTrue(walletsTab.waitForExistence(timeout: 10))
        walletsTab.tap()
        XCTAssertTrue(app.navigationBars["Wallets"].waitForExistence(timeout: 5))
        openAddExpense(in: app)
        XCTAssertTrue(app.navigationBars["Add Expense"].waitForExistence(timeout: 5))
        app.buttons["closeAddExpense"].tap()
        XCTAssertTrue(app.navigationBars["Wallets"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testKeyboardDonePreservesExpenseDraftAndAllowsTabNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openAddExpense(in: app)

        let amount = app.textFields["expenseAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10))
        amount.tap()
        amount.typeText("123")
        dismissExpenseKeyboard(in: app)
        XCTAssertEqual(amount.value as? String, "123")

        let note = app.textFields["expenseNote"]
        note.tap()
        note.typeText("Unfinished expense")
        dismissExpenseKeyboard(in: app)
        XCTAssertEqual(note.value as? String, "Unfinished expense")
        XCTAssertEqual(amount.value as? String, "123")
        XCTAssertFalse(app.alerts["Expense Added"].exists)

        app.buttons["closeAddExpense"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Wallets"].tap()
        XCTAssertTrue(app.navigationBars["Wallets"].waitForExistence(timeout: 5))
        openAddExpense(in: app)
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "123")
        XCTAssertEqual(note.value as? String, "Unfinished expense")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    @MainActor
    func testNoteReturnDismissesKeyboardWithoutSaving() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openAddExpense(in: app)

        let note = app.textFields["expenseNote"]
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        note.tap()
        note.typeText("Draft note\n")
        assertKeyboardHidden(in: app)
        XCTAssertEqual(note.value as? String, "Draft note")
        XCTAssertFalse(app.alerts["Expense Added"].exists)
    }

    @MainActor
    private func openAddExpense(in app: XCUIApplication) {
        let add = app.buttons["openAddExpense"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
    }

    @MainActor
    private func dismissExpenseKeyboard(in app: XCUIApplication) {
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let done = app.buttons["dismissExpenseKeyboard"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        assertKeyboardHidden(in: app)
    }

    @MainActor
    private func assertKeyboardHidden(in app: XCUIApplication) {
        let hidden = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.keyboards.firstMatch
        )
        wait(for: [hidden], timeout: 5)
    }
}
