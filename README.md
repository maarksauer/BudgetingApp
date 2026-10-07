# Budgeting App

A SwiftUI and SwiftData budgeting app. Open `Budgeting App.xcodeproj` in Xcode and select the shared **Budgeting App** scheme.

## Open the project

Extract the downloaded ZIP into its own folder, then double-click `Budgeting App.xcodeproj` inside it. Xcode will show the app and test groups in the project navigator.

The repository has one level of project folders:

```text
BudgetingApp/
├── Budgeting App.xcodeproj
├── Budgeting App/
├── Budgeting AppTests/
├── Budgeting AppUITests/
└── README.md
```

## Home dashboard

The app opens on Home with this month's spending, income and net cash flow, wallet balances, current budget progress, and the next active recurring bills. Currencies have separate spending totals. Wallet balances include transfers, budget spending matches its categories/currency/date range, and bills use their postponed dates when applicable. Overdue bills appear first; paused bills are excluded.

Tap a wallet, budget, or bill to open its existing detail screen, or use **See all** to open the full list. Recurring monthly budgets catch up on Home as well as on Budgets.

**Add Transaction** is available above the tab bar on each main screen. Choose **Expense** or **Income** at the top. Income needs a positive amount and a wallet; use the source/note field for Salary, Refund, or another description. Income does not require a spending category or sufficient existing funds. Expenses retain their category and balance-limit checks. **Close** returns to the screen you were using and keeps the unfinished transaction, including its type, for the current app session. The keyboard's **Done** button still dismisses it without saving.

## Income support

- Wallet balance is starting balance + income − expenses − outgoing transfers + incoming transfers. All wallet, expense, bill-payment, and transfer screens share the same calculation.
- Home shows income and net cash flow (income minus expenses) separately for each currency. Transfers do not count as income or spending.
- Income appears with a green plus amount and an income label in Transactions, and a green plus amount in wallet history. Searching for `income` or `expense` matches the transaction type as well as existing search fields.
- Open an income transaction to edit its amount, date, note, or wallet, or to delete it. Its transaction type stays fixed when editing. Reducing, moving, or deleting income adjusts the affected balances, even if that exposes a negative balance; expense and transfer creation still enforce each wallet's spending limit.
- Income never uses up a category budget. Recurring bill payments continue to create expenses.
- The stored `ExpenseTransaction` model name is retained. The only added stored field is `isIncome: Bool = false`, intended for a lightweight migration that treats previous records as expenses. Verify this upgrade against existing on-device data before relying on it; the migration could not be run in this environment.
- Saving a new transaction confirms only after `modelContext.save()` succeeds. If it fails, the draft remains available to retry.

### Try this in Xcode

1. Run this version over your existing installation and confirm old expenses, wallets, budgets, and recurring bills still load.
2. On **Add Transaction → Income**, save Salary of **685,000 HUF** into a wallet. Its balance and Home income should increase by 685,000 HUF, while spending and budgets stay the same.
3. Record an expense of **5,000 HUF** from that wallet. With just these two transactions this month, net cash flow should be **680,000 HUF**.
4. Check income can be saved into an empty wallet without selecting a category. Check income works with an overdrawn wallet and a credit-card wallet as well.
5. Edit the income amount and then move it to another wallet of the same currency; verify both balances. Delete it and verify that it no longer appears in Home income or wallet history.
6. Add income in EUR as well as HUF and check each currency stays separate. Add a transfer and verify it affects wallet balances without changing cash flow.
7. Close an unfinished income, change tabs, and reopen Add Transaction; type, amount, and note should be preserved. Restart the app after saving and confirm the income still exists.

## Build and test on a Mac

Use Xcode with SDKs and a simulator runtime supporting the project's deployment targets (currently 26.5). The project metadata records Xcode 26.6. Linux cannot build or run this app because SwiftUI, SwiftData, and Apple simulators require Apple's toolchain.

From the repository root, inspect your installed SDKs and simulator destinations:

```sh
xcodebuild -version
xcodebuild -showsdks
xcodebuild -list -project "Budgeting App.xcodeproj"
xcodebuild -showdestinations -project "Budgeting App.xcodeproj" -scheme "Budgeting App"
```

Choose an available iPhone simulator with an OS meeting the deployment target. Replace `SIMULATOR_UUID` with its identifier:

```sh
xcodebuild -project "Budgeting App.xcodeproj" -scheme "Budgeting App" \
  -configuration Debug -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath /tmp/budgeting-app-derived build

xcodebuild -project "Budgeting App.xcodeproj" -scheme "Budgeting App" \
  -configuration Debug -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath /tmp/budgeting-app-derived test
```

The scheme includes fifteen unit tests covering wallet balances, overdraft limits, recurring-payment rescheduling, paused payments, monthly totals by currency, transfer amounts, budget date/category/currency matching, bill ordering, and recurring-budget catch-up without duplicate pending periods. Income tests also cover decimal balances with transfers, monthly income/cash flow, spending/budget exclusions, persistent edits and wallet moves, deletion, and store reopening. Four UI tests cover Home/navigation, reopening expense and income drafts, and keyboard dismissal. Run the UI tests on an iPhone simulator with the software keyboard enabled, where the tab bar is visible. Test sources belong only to their test targets; app sources and assets belong only to the app target. `Info.plist` is processed as build configuration, not copied as a resource.

On Add Transaction, use **Done** above the keyboard or drag the form to dismiss it. The note field's Done/Return key also dismisses the keyboard. Dismissing preserves the entered amount and note. Check this with no wallet configured as well as with a valid expense draft, and verify that you can open another tab afterward without creating a transaction.

Check Home with no data, with wallets in multiple currencies, with incoming/outgoing transfers, with an overspent budget, and with overdue/postponed/paused bills. Confirm that saving an expense refreshes the spending and budget cards. Close an unfinished expense, open another tab, and reopen Add Transaction to verify that its draft remains.

For a physical device or distribution, configure your own signing team in Xcode. Build and test commands above still need validation on macOS; Linux checks only establish project structure and file-reference integrity.
