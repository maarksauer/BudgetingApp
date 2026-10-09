import XCTest
import Foundation

final class BudgetingAppUITests: XCTestCase {
    @MainActor
    func testLaunchOnCentralAddTabAndOverviewNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.navigationBars["Add Transaction"].waitForExistence(timeout: 10))
        let tabIDs = ["tabOverview", "tabTransactions", "tabAdd", "tabWallets", "tabMore"]
        let tabs = tabIDs.map { app.buttons[$0] }
        for tab in tabs { XCTAssertTrue(tab.exists && tab.isHittable) }
        XCTAssertTrue(tabs[2].isSelected)
        for index in 0..<4 {
            XCTAssertLessThan(tabs[index].frame.midX, tabs[index + 1].frame.midX)
        }
        XCTAssertGreaterThan(tabs[2].frame.height, tabs[1].frame.height)
        XCTAssertFalse(app.buttons["openAddExpense"].exists)
        XCTAssertFalse(app.buttons["closeAddExpense"].exists)

        tabs[0].tap()
        XCTAssertTrue(app.navigationBars["Overview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Spent this month"].exists)
        XCTAssertTrue(app.staticTexts["Income this month"].exists)
        XCTAssertFalse(app.buttons["openAddExpense"].exists)
        let budgets = app.buttons["See all current budgets"]
        for _ in 0..<12 {
            if budgets.exists && budgets.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(budgets.exists && budgets.isHittable)
        budgets.tap()
        XCTAssertTrue(app.navigationBars["Budgets"].waitForExistence(timeout: 5))
        app.navigationBars["Budgets"].buttons["More"].tap()
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["openBudgets"].exists)

        tabs[3].tap()
        XCTAssertTrue(app.navigationBars["Wallets"].waitForExistence(timeout: 5))
        openAddExpense(in: app)
        XCTAssertTrue(app.navigationBars["Add Transaction"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["closeAddExpense"].exists)
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
        XCTAssertFalse(app.alerts["Transaction Added"].exists)

        app.buttons["tabOverview"].tap()
        XCTAssertTrue(app.navigationBars["Overview"].waitForExistence(timeout: 5))
        app.buttons["tabWallets"].tap()
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
        XCTAssertFalse(app.alerts["Transaction Added"].exists)
    }

    @MainActor
    func testIncomeDraftKeepsTypeAndValuesAcrossTabs() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openAddExpense(in: app)
        let type = app.segmentedControls["transactionType"]
        XCTAssertTrue(type.waitForExistence(timeout: 5))
        type.buttons["Income"].tap()

        let amount = app.textFields["expenseAmount"]
        amount.tap()
        amount.typeText("685000")
        dismissExpenseKeyboard(in: app)
        let note = app.textFields["expenseNote"]
        note.tap()
        note.typeText("Salary")
        dismissExpenseKeyboard(in: app)
        XCTAssertFalse(app.staticTexts["Select Category"].exists)
        XCTAssertFalse(app.alerts["Transaction Added"].exists)

        app.buttons["tabWallets"].tap()
        openAddExpense(in: app)
        XCTAssertTrue(type.buttons["Income"].isSelected)
        XCTAssertEqual(amount.value as? String, "685000")
        XCTAssertEqual(note.value as? String, "Salary")
        XCTAssertFalse(app.keyboards.firstMatch.exists)

        type.buttons["Expense"].tap()
        XCTAssertTrue(type.buttons["Expense"].isSelected)
        XCTAssertEqual(amount.value as? String, "685000")
        XCTAssertEqual(note.value as? String, "Salary")
    }

    @MainActor
    func testOverviewCategoryBreakdownAndRecentTransactionsNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        app.buttons["tabOverview"].tap()
        XCTAssertTrue(app.navigationBars["Overview"].waitForExistence(timeout: 10))
        let recent = app.buttons["See all recent transactions"]
        for _ in 0..<12 {
            if recent.exists && recent.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(recent.exists && recent.isHittable)
        XCTAssertTrue(app.staticTexts["Recent transactions"].exists)
        let categories = app.staticTexts["Spending by category"]
        for _ in 0..<12 {
            if categories.exists && categories.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(categories.exists && categories.isHittable)
        for _ in 0..<12 {
            if recent.exists && recent.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(recent.isHittable)
        recent.tap()
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["openAddExpense"].exists)
        XCTAssertTrue(app.buttons["tabAdd"].exists)
    }

    @MainActor
    func testExportDataScreenOptionsAndEmptyState() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        app.buttons["tabMore"].tap()
        let export = app.buttons["openExportData"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        XCTAssertTrue(app.navigationBars["Export Data"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rows to export"].exists)
        let includeTransfers = app.switches["csvIncludeTransfers"]
        XCTAssertTrue(includeTransfers.exists)
        includeTransfers.tap()
        includeTransfers.tap()
        let dateRange = app.switches["csvUseDateRange"]
        XCTAssertTrue(dateRange.exists)
        dateRange.tap()
        XCTAssertTrue(app.staticTexts["From"].exists)
        XCTAssertTrue(app.staticTexts["To"].exists)
        dateRange.tap()
        XCTAssertTrue(app.staticTexts["All saved transactions"].exists)
        let save = app.buttons["saveTransactionCSV"]
        for _ in 0..<6 {
            if save.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(save.exists)
        XCTAssertTrue(app.buttons["shareTransactionCSV"].exists)
        if app.staticTexts["No transactions match these options."].exists {
            XCTAssertFalse(save.isEnabled)
            XCTAssertFalse(app.buttons["shareTransactionCSV"].isEnabled)
        }
    }

    @MainActor
    func testBackupRestoreNavigationAndActions() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        app.buttons["tabMore"].tap()
        let backup = app.buttons["openBackupRestore"].firstMatch
        for _ in 0..<6 {
            if backup.exists && backup.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(backup.waitForExistence(timeout: 5))
        backup.tap()
        XCTAssertTrue(app.navigationBars["Backup & Restore"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["saveAppBackup"].exists)
        XCTAssertTrue(app.buttons["saveAppBackup"].isEnabled)
        let choose = app.buttons["chooseAppBackup"]
        for _ in 0..<6 {
            if choose.exists && choose.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(choose.exists)
        XCTAssertTrue(choose.isEnabled)
        XCTAssertFalse(app.buttons["restoreAppBackup"].exists)
    }

    @MainActor
    func testWalletAndBudgetFormKeyboardDoneKeepsDraftAndValidation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        app.buttons["tabWallets"].tap()
        app.buttons["openCreateWallet"].tap()
        XCTAssertTrue(app.navigationBars["New Wallet"].waitForExistence(timeout: 5))
        let walletName = app.textFields["walletFormName"]
        walletName.tap(); walletName.typeText("Draft wallet")
        app.buttons["walletFormKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertEqual(walletName.value as? String, "Draft wallet")
        let balance = app.textFields["walletFormBalance"]
        for _ in 0..<6 {
            if balance.exists && balance.isHittable { break }
            app.swipeUp()
        }
        balance.tap(); balance.typeText("100")
        app.buttons["walletFormKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertEqual(balance.value as? String, "100")
        XCTAssertTrue(app.buttons["createWallet"].isEnabled)
        app.buttons["cancelWalletForm"].tap()
        XCTAssertTrue(app.navigationBars["Wallets"].waitForExistence(timeout: 5))

        app.buttons["tabMore"].tap()
        app.buttons["openBudgets"].tap()
        app.buttons["openCreateBudget"].tap()
        XCTAssertTrue(app.navigationBars["New Budget"].waitForExistence(timeout: 5))
        let budgetName = app.textFields["budgetFormName"]
        budgetName.tap(); budgetName.typeText("Draft budget")
        app.buttons["budgetFormKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        let amount = app.textFields["budgetFormAmount"]
        for _ in 0..<6 {
            if amount.exists && amount.isHittable { break }
            app.swipeUp()
        }
        amount.tap(); amount.typeText("0")
        app.buttons["budgetFormKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertEqual(amount.value as? String, "0")
        XCTAssertFalse(app.buttons["createBudget"].isEnabled)
        XCTAssertTrue(app.staticTexts["Enter a complete amount greater than zero."].exists)
        app.buttons["cancelBudgetForm"].tap()
        XCTAssertTrue(app.navigationBars["Budgets"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTransactionCreationAndEditingKeyboardValidationAndCancel() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let walletName = createFormTestWallet(in: app)
        app.buttons["tabAdd"].tap()
        chooseFormWallet(walletName, prefix: "expense", in: app)
        XCTAssertTrue(app.buttons["expenseCategory"].exists)
        let available = app.descendants(matching: .any)["expenseAvailableAmount"].firstMatch
        for _ in 0..<10 {
            app.swipeUp()
            if available.exists && available.isHittable { break }
        }
        XCTAssertTrue(available.exists && available.isHittable)
        // The final balance row must fit above the dock, including its larger + button.
        XCTAssertLessThanOrEqual(available.frame.maxY, app.buttons["tabAdd"].frame.minY)
        let amount = app.textFields["expenseAmount"]
        for _ in 0..<10 {
            if amount.exists && amount.isHittable { break }
            app.swipeDown()
        }
        amount.tap(); amount.typeText("12.25")
        dismissExpenseKeyboard(in: app)
        let noteValue = "UI expense \(UUID().uuidString.prefix(8))"
        let note = app.textFields["expenseNote"]
        note.tap(); note.typeText(noteValue)
        dismissExpenseKeyboard(in: app)
        let add = app.buttons["saveTransaction"]
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(app.alerts["Transaction Added"].waitForExistence(timeout: 5))
        app.alerts["Transaction Added"].buttons["OK"].tap()
        app.buttons["tabTransactions"].tap()
        let search = app.searchFields.firstMatch
        for _ in 0..<8 {
            if search.exists && search.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(search.exists && search.isHittable)
        search.tap(); search.typeText(noteValue + "\n")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", noteValue)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["editTransaction"].tap()
        XCTAssertTrue(app.navigationBars["Edit Transaction"].waitForExistence(timeout: 5))
        let editAmount = app.textFields["transactionEditAmount"]
        replaceFormText(editAmount, with: "0")
        app.buttons["transactionEditKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertFalse(app.buttons["saveTransactionEdit"].isEnabled)
        replaceFormText(editAmount, with: "12.75")
        app.buttons["transactionEditKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertEqual(editAmount.value as? String, "12.75")
        app.buttons["saveTransactionEdit"].tap()
        XCTAssertTrue(app.navigationBars["Transaction"].waitForExistence(timeout: 5))
        app.buttons["editTransaction"].tap()
        XCTAssertEqual(editAmount.value as? String, "12.75")
        replaceFormText(editAmount, with: "999")
        app.buttons["transactionEditKeyboardDone"].tap()
        app.buttons["cancelTransactionEdit"].tap()
        app.buttons["editTransaction"].tap()
        XCTAssertEqual(editAmount.value as? String, "12.75")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.buttons["cancelTransactionEdit"].tap()
    }

    @MainActor
    func testRecurringCreationEditingAndConfirmationKeyboardAndSaveFlow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let walletName = createFormTestWallet(in: app)
        app.buttons["tabMore"].tap()
        app.buttons["openRecurringPayments"].tap()
        app.buttons["openCreateRecurringPayment"].tap()
        XCTAssertTrue(app.navigationBars["New Recurring Payment"].waitForExistence(timeout: 5))
        let paymentName = "UI bill \(UUID().uuidString.prefix(8))"
        let name = app.textFields["recurringFormName"]
        name.tap(); name.typeText(paymentName + "\n")
        let amount = app.textFields["recurringFormAmount"]
        amount.typeText("0")
        app.buttons["recurringFormKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertEqual(name.value as? String, paymentName)
        XCTAssertFalse(app.buttons["createRecurringPayment"].isEnabled)
        replaceFormText(amount, with: "5.50")
        app.buttons["recurringFormKeyboardDone"].tap()
        chooseFormWallet(walletName, prefix: "recurringForm", in: app)
        XCTAssertTrue(app.buttons["createRecurringPayment"].isEnabled)
        app.buttons["createRecurringPayment"].tap()
        XCTAssertTrue(app.navigationBars["Recurring Payments"].waitForExistence(timeout: 5))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", paymentName)).firstMatch
        for _ in 0..<12 {
            if row.exists && row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.exists && row.isHittable)
        row.tap()
        app.buttons["editRecurringPayment"].tap()
        XCTAssertTrue(app.navigationBars["Edit Recurring Payment"].waitForExistence(timeout: 5))
        replaceFormText(amount, with: "0")
        app.buttons["recurringFormKeyboardDone"].tap()
        XCTAssertFalse(app.buttons["saveRecurringPaymentEdit"].isEnabled)
        app.buttons["cancelRecurringForm"].tap()
        app.buttons["editRecurringPayment"].tap()
        XCTAssertEqual(amount.value as? String, "5.5")
        replaceFormText(amount, with: "6.25")
        app.buttons["recurringFormKeyboardDone"].tap()
        app.buttons["saveRecurringPaymentEdit"].tap()
        XCTAssertTrue(app.navigationBars[paymentName].waitForExistence(timeout: 5))
        let confirm = app.buttons["openConfirmPayment"]
        for _ in 0..<12 {
            if confirm.exists && confirm.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(confirm.exists && confirm.isHittable)
        confirm.tap()
        let actual = app.textFields["confirmPaymentAmount"]
        XCTAssertTrue(actual.waitForExistence(timeout: 5))
        XCTAssertEqual(actual.value as? String, "6.25")
        replaceFormText(actual, with: "0")
        app.buttons["confirmPaymentKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertFalse(app.buttons["confirmRecurringPayment"].isEnabled)
        replaceFormText(actual, with: "4.75")
        app.buttons["confirmPaymentKeyboardDone"].tap()
        XCTAssertEqual(actual.value as? String, "4.75")
        app.buttons["cancelConfirmPayment"].tap()
        confirm.tap()
        XCTAssertEqual(actual.value as? String, "6.25")
        replaceFormText(actual, with: "4.75")
        app.buttons["confirmPaymentKeyboardDone"].tap()
        app.buttons["confirmRecurringPayment"].tap()
        XCTAssertTrue(app.navigationBars[paymentName].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["openConfirmPayment"].exists)
        XCTAssertTrue(app.staticTexts["Last Payment"].exists)
    }

    @MainActor
    func testSameCurrencyTransferKeyboardSaveEditAndCancel() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let sourceName = createFormTestWallet(in: app)
        let destinationName = createFormTestWallet(in: app)
        openFormTestWallet(sourceName, in: app)
        let open = app.buttons["openCreateTransfer"]
        scrollToFormElement(open, in: app)
        open.tap()
        XCTAssertTrue(app.navigationBars["New Transfer"].waitForExistence(timeout: 5))
        chooseFormWallet(destinationName, prefix: "transferDestination", in: app)
        let sent = app.textFields["transferSentAmount"]
        scrollToFormElement(sent, in: app, upward: false)
        sent.tap(); sent.typeText("12.25")
        app.buttons["transferKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertEqual(sent.value as? String, "12.25")
        XCTAssertFalse(app.textFields["transferReceivedAmount"].exists)
        let noteValue = "UI transfer \(UUID().uuidString.prefix(8))"
        let note = app.textFields["transferNote"]
        scrollToFormElement(note, in: app)
        note.tap(); note.typeText(noteValue + "\n")
        assertKeyboardHidden(in: app)
        XCTAssertEqual(note.value as? String, noteValue)
        XCTAssertTrue(app.buttons["createTransfer"].isEnabled)
        app.buttons["createTransfer"].tap()
        XCTAssertTrue(app.navigationBars[sourceName].waitForExistence(timeout: 5))
        openTransferByNote(noteValue, in: app)
        app.buttons["editTransfer"].tap()
        XCTAssertTrue(app.navigationBars["Edit Transfer"].waitForExistence(timeout: 5))
        replaceFormText(sent, with: "0")
        app.buttons["transferKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertFalse(app.buttons["saveTransferEdit"].isEnabled)
        replaceFormText(sent, with: "12.75")
        app.buttons["transferKeyboardDone"].tap()
        app.buttons["saveTransferEdit"].tap()
        XCTAssertTrue(app.navigationBars["Transfer"].waitForExistence(timeout: 5))
        app.buttons["editTransfer"].tap()
        XCTAssertEqual(sent.value as? String, "12.75")
        replaceFormText(sent, with: "999")
        app.buttons["transferKeyboardDone"].tap()
        app.buttons["cancelTransferForm"].tap()
        app.buttons["editTransfer"].tap()
        XCTAssertEqual(sent.value as? String, "12.75")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.buttons["cancelTransferForm"].tap()
    }

    @MainActor
    func testCrossCurrencyTransferNextDoneAndBothAmountsSurviveSave() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let sourceName = createFormTestWallet(in: app, currency: "EUR")
        let destinationName = createFormTestWallet(in: app, currency: "HUF")
        openFormTestWallet(sourceName, in: app)
        let open = app.buttons["openCreateTransfer"]
        scrollToFormElement(open, in: app); open.tap()
        chooseFormWallet(destinationName, prefix: "transferDestination", in: app)
        let sent = app.textFields["transferSentAmount"]
        scrollToFormElement(sent, in: app, upward: false)
        sent.tap(); sent.typeText("50")
        let next = app.buttons["transferKeyboardNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 5)); next.tap()
        let received = app.textFields["transferReceivedAmount"]
        XCTAssertTrue(received.waitForExistence(timeout: 5))
        received.typeText("20000")
        app.buttons["transferKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertEqual(sent.value as? String, "50")
        XCTAssertEqual(received.value as? String, "20000")
        let noteValue = "UI exchange \(UUID().uuidString.prefix(8))"
        let note = app.textFields["transferNote"]
        scrollToFormElement(note, in: app)
        note.tap(); note.typeText(noteValue)
        app.buttons["transferKeyboardDone"].tap()
        assertKeyboardHidden(in: app)
        XCTAssertTrue(app.buttons["createTransfer"].isEnabled)
        app.buttons["createTransfer"].tap()
        XCTAssertTrue(app.navigationBars[sourceName].waitForExistence(timeout: 5))
        openTransferByNote(noteValue, in: app)
        app.buttons["editTransfer"].tap()
        XCTAssertTrue(app.navigationBars["Edit Transfer"].waitForExistence(timeout: 5))
        XCTAssertEqual(sent.value as? String, "50")
        XCTAssertEqual(received.value as? String, "20000")
        scrollToFormElement(received, in: app)
        replaceFormText(received, with: "0")
        app.buttons["transferKeyboardDone"].tap()
        XCTAssertFalse(app.buttons["saveTransferEdit"].isEnabled)
        app.buttons["cancelTransferForm"].tap()
        app.buttons["editTransfer"].tap()
        XCTAssertEqual(received.value as? String, "20000")
        app.buttons["cancelTransferForm"].tap()
    }

    @MainActor
    func testTransactionListTypeFiltersApplyCancelChipsAndNoResults() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let wallet = createFormTestWallet(in: app)
        openAddExpense(in: app)
        app.segmentedControls["transactionType"].buttons["Income"].tap()
        chooseFormWallet(wallet, prefix: "expense", in: app)
        let amount = app.textFields["expenseAmount"]
        scrollToFormElement(amount, in: app, upward: false)
        amount.tap(); amount.typeText("25")
        dismissExpenseKeyboard(in: app)
        let noteValue = "Kávé UI \(UUID().uuidString.prefix(8))"
        let note = app.textFields["expenseNote"]
        scrollToFormElement(note, in: app)
        note.tap(); note.typeText(noteValue)
        dismissExpenseKeyboard(in: app)
        app.buttons["saveTransaction"].tap()
        XCTAssertTrue(app.alerts["Transaction Added"].waitForExistence(timeout: 5))
        app.alerts["Transaction Added"].buttons["OK"].tap()
        app.buttons["tabTransactions"].tap()
        let search = app.searchFields.firstMatch
        scrollToFormElement(search, in: app, upward: false)
        search.tap(); search.typeText(noteValue.replacingOccurrences(of: "Kávé", with: "kave") + "\n")
        assertKeyboardHidden(in: app)
        let row = app.buttons["transactionRow-\(noteValue)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.buttons["transactionType-Expenses"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["transactionNoResults"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
        app.buttons["transactionType-Income"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        app.buttons["openTransactionFilters"].tap()
        let walletPicker = app.buttons["transactionFilterWallet"]
        walletPicker.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", wallet)).firstMatch.tap()
        app.buttons["cancelTransactionFilters"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["removeWalletFilter"].exists)

        app.buttons["openTransactionFilters"].tap()
        walletPicker.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", wallet)).firstMatch.tap()
        app.buttons["applyTransactionFilters"].tap()
        XCTAssertTrue(app.buttons["removeWalletFilter"].waitForExistence(timeout: 5))
        XCTAssertTrue(row.exists)
        app.buttons["removeWalletFilter"].tap()
        XCTAssertFalse(app.buttons["removeWalletFilter"].exists)
        app.buttons["resetTransactionFilters"].tap()
        XCTAssertTrue(row.exists)
        row.tap()
        XCTAssertTrue(app.navigationBars["Transaction"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBudgetPeriodTabsKeepCurrentBudgetAndOpenDetails() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        app.buttons["tabMore"].tap()
        app.buttons["openBudgets"].tap()
        let name = createPolishTestBudget(in: app)
        let row = app.buttons["budgetRow-\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.buttons["budgetPeriod-Upcoming"].tap()
        XCTAssertFalse(row.exists)
        app.buttons["budgetPeriod-Past"].tap()
        XCTAssertFalse(row.exists)
        app.buttons["budgetPeriod-All"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.buttons["budgetPeriod-Current"].tap()
        row.tap()
        XCTAssertTrue(app.buttons["manageBudgetCategories"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Within Budget"].exists)
        XCTAssertTrue(app.staticTexts["Choose categories to track spending."].exists)
    }

    @MainActor
    func testLargeTextDarkModeDockBudgetAndOverviewNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-appAppearance", "dark"]
        app.launch()
        XCTAssertTrue(app.buttons["tabAdd"].waitForExistence(timeout: 10))
        for id in ["tabOverview", "tabTransactions", "tabAdd", "tabWallets", "tabMore"] {
            let tab = app.buttons[id]
            XCTAssertTrue(tab.exists && tab.isHittable)
            XCTAssertLessThanOrEqual(tab.frame.maxY, app.frame.maxY)
        }
        let amount = app.textFields["expenseAmount"]
        scrollToFormElement(amount, in: app, upward: false)
        amount.tap(); amount.typeText("12.25")
        dismissExpenseKeyboard(in: app)
        XCTAssertEqual(amount.value as? String, "12.25")
        XCTAssertTrue(app.buttons["tabMore"].isHittable)
        app.buttons["tabMore"].tap()
        scrollToFormElement(app.buttons["openBudgets"], in: app)
        app.buttons["openBudgets"].tap()
        let name = createPolishTestBudget(in: app)
        let row = app.buttons["budgetRow-\(name)"]
        scrollToFormElement(row, in: app)
        XCTAssertTrue(row.isHittable)
        // Scroll the card's lower content into view; the dock must retain its own space.
        app.swipeUp()
        XCTAssertTrue(app.buttons["tabMore"].isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Budgets — large text and dark mode"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["tabOverview"].tap()
        XCTAssertTrue(app.navigationBars["Overview"].waitForExistence(timeout: 5))
        app.buttons["tabWallets"].tap()
        XCTAssertTrue(app.navigationBars["Wallets"].waitForExistence(timeout: 5))
        app.buttons["tabTransactions"].tap()
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 5))
        app.buttons["tabAdd"].tap()
        scrollToFormElement(amount, in: app, upward: false)
        XCTAssertEqual(amount.value as? String, "12.25")
    }

    @MainActor
    func testWalletAndMoreSummaryRowsKeepLabelsAndCompactHeightInDarkMode() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL", "-appAppearance", "dark"]
        app.launch()
        let name = createFormTestWallet(in: app)
        let wallet = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(wallet.waitForExistence(timeout: 5))
        scrollToFormElement(wallet, in: app)
        XCTAssertTrue(wallet.label.contains(name))
        XCTAssertLessThan(wallet.frame.height, 120, "A normal wallet row must not stretch into a large blank card.")
        wallet.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
        app.buttons["tabMore"].tap()
        let currencies = app.buttons["openCurrenciesSettings"]
        scrollToFormElement(currencies, in: app)
        XCTAssertTrue(currencies.label.contains("Currencies"))
        XCTAssertLessThan(currencies.frame.height, 100)
        let appearance = app.buttons["openAppearanceSettings"]
        scrollToFormElement(appearance, in: app)
        XCTAssertTrue(appearance.label.contains("Appearance"))
        XCTAssertLessThan(appearance.frame.height, 100)
        appearance.tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tabMore"].isHittable)
    }

    @MainActor
    private func createPolishTestBudget(in app: XCUIApplication) -> String {
        app.buttons["openCreateBudget"].tap()
        let name = "UI budget with a longer descriptive name \(UUID().uuidString.prefix(8))"
        let field = app.textFields["budgetFormName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(name)
        app.buttons["budgetFormKeyboardDone"].tap()
        let amount = app.textFields["budgetFormAmount"]
        scrollToFormElement(amount, in: app)
        amount.tap(); amount.typeText("123456.75")
        app.buttons["budgetFormKeyboardDone"].tap()
        XCTAssertTrue(app.buttons["createBudget"].isEnabled)
        app.buttons["createBudget"].tap()
        XCTAssertTrue(app.navigationBars["Budgets"].waitForExistence(timeout: 5))
        return name
    }

    @MainActor
    private func openFormTestWallet(_ name: String, in app: XCUIApplication) {
        app.buttons["tabWallets"].tap()
        let wallet = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        scrollToFormElement(wallet, in: app)
        wallet.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openTransferByNote(_ note: String, in app: XCUIApplication) {
        app.buttons["tabTransactions"].tap()
        let search = app.searchFields.firstMatch
        scrollToFormElement(search, in: app, upward: false)
        search.tap(); search.typeText(note + "\n")
        assertKeyboardHidden(in: app)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", note)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["Transfer"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func scrollToFormElement(_ element: XCUIElement, in app: XCUIApplication, upward: Bool = true) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { break }
            if upward { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    @MainActor
    private func createFormTestWallet(in app: XCUIApplication, currency: String? = nil) -> String {
        let name = "UI wallet \(UUID().uuidString.prefix(8))"
        app.buttons["tabWallets"].tap()
        app.buttons["openCreateWallet"].tap()
        let field = app.textFields["walletFormName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(name)
        app.buttons["walletFormKeyboardDone"].tap()
        if let currency {
            let picker = app.buttons["walletFormCurrency"]
            scrollToFormElement(picker, in: app)
            picker.tap()
            let choice = app.buttons[currency].firstMatch
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
        }
        let balance = app.textFields["walletFormBalance"]
        for _ in 0..<8 {
            if balance.exists && balance.isHittable { break }
            app.swipeUp()
        }
        balance.tap(); balance.typeText("1000")
        app.buttons["walletFormKeyboardDone"].tap()
        app.buttons["createWallet"].tap()
        XCTAssertTrue(app.navigationBars["Wallets"].waitForExistence(timeout: 5))
        return name
    }

    @MainActor
    private func chooseFormWallet(_ name: String, prefix: String, in app: XCUIApplication) {
        let picker = app.buttons["\(prefix)Wallet"]
        for _ in 0..<10 {
            if picker.exists && picker.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(picker.exists && picker.isHittable)
        picker.tap()
        let matches = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name))
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 5))
        guard let choice = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("The wallet menu should contain the newly created wallet.")
            return
        }
        choice.tap()
    }

    @MainActor
    private func replaceFormText(_ field: XCUIElement, with text: String) {
        for _ in 0..<8 {
            if field.exists && field.isHittable { break }
            XCUIApplication().swipeDown()
        }
        XCTAssertTrue(field.exists && field.isHittable)
        field.tap()
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + text)
        XCTAssertEqual(field.value as? String, text)
    }

    @MainActor
    private func openAddExpense(in app: XCUIApplication) {
        let add = app.buttons["tabAdd"].firstMatch
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
