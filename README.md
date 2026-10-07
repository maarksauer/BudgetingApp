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

The app opens on Home with this month's spending, wallet balances, current budget progress, and the next active recurring bills. Currencies have separate spending totals. Wallet balances include transfers, budget spending matches its categories/currency/date range, and bills use their postponed dates when applicable. Overdue bills appear first; paused bills are excluded.

Tap a wallet, budget, or bill to open its existing detail screen, or use **See all** to open the full list. Recurring monthly budgets catch up on Home as well as on Budgets.

**Add Expense** is available above the tab bar on each main screen. **Close** returns to the screen you were using and keeps the unfinished expense for the current app session. The keyboard's **Done** button still dismisses it without saving.

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

The scheme includes ten unit tests covering wallet balances, overdraft limits, recurring-payment rescheduling, paused payments, monthly totals by currency, transfer amounts, budget date/category/currency matching, bill ordering, and recurring-budget catch-up without duplicate pending periods. Three UI tests cover Home/navigation, reopening expense drafts, and keyboard dismissal. Run the UI tests on an iPhone simulator with the software keyboard enabled, where the tab bar is visible. Test sources belong only to their test targets; app sources and assets belong only to the app target. `Info.plist` is processed as build configuration, not copied as a resource.

On Add Expense, use **Done** above the keyboard or drag the form to dismiss it. The note field's Done/Return key also dismisses the keyboard. Dismissing preserves the entered amount and note. Check this with no wallet configured as well as with a valid expense draft, and verify that you can open another tab afterward without creating a transaction.

Check Home with no data, with wallets in multiple currencies, with incoming/outgoing transfers, with an overspent budget, and with overdue/postponed/paused bills. Confirm that saving an expense refreshes the spending and budget cards. Close an unfinished expense, open another tab, and reopen Add Expense to verify that its draft remains.

For a physical device or distribution, configure your own signing team in Xcode. Build and test commands above still need validation on macOS; Linux checks only establish project structure and file-reference integrity.
