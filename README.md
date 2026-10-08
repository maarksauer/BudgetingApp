# Budgeting App

A SwiftUI and SwiftData budgeting app. Open `Budgeting App.xcodeproj` in Xcode and select the shared **Budgeting App** scheme.

## Combined budget and layout polish

Budgets opens on **Current**, with **Upcoming**, **Past**, and **All** tabs and a matching budget count. Current includes the entire starting and ending days. Past periods are immediately accessible instead of hidden in a collapsed section; All shows saved periods newest first. Each empty period has a Create Budget action and a Show All Budgets action, and the completely empty installation explains how to start. Recurring budget catch-up still runs when the screen opens, on a new day, and when the app becomes active. This update does not add monthly reports.

Budget cards show their exact **Spent** and **Remaining** currency amounts, period dates, time remaining, and percentage used. **Near Limit** appears at 80%, **Limit Reached** at exactly 100%, and **Over Budget** beyond it. The progress bar stops at full while the displayed percentage and exceeded amount continue beyond 100%. Warning text and symbols accompany colour so the status is understandable without colour alone. Budgets with no selected categories explain that categories are needed to track spending. Overview and budget details reuse the same presentation and existing expense/date/category/currency matching rules; income and transfers remain excluded.

Budget details provide **Previous Period** and **Next Period** links when other saved periods exist in the same recurring series. These links never generate a period or cross into an unrelated budget with the same name. Category spending shows its currency beside each amount. Create/edit/category-selection and deletion behaviour retain their existing data handling.

The source layout review covered all app screens. Shared label/value rows now stack at accessibility text sizes and fall back to a vertical layout when names and amounts cannot fit side by side. This applies to Overview totals/category spending/wallets/bills, wallet rows and history, transaction/transfer/recurring rows, budget cards, settings summaries, and read-only detail/backup/export rows. Add/edit transaction and transfer amount fields move the currency below the input at accessibility sizes. Due/postponed recurring actions stack, use flexible button heights, and provide a named Skip action.

The central + dock keeps its separate reserved layout space. At accessibility text sizes it shows the five icons without crowding oversized captions; the full destination labels and selected-state traits remain available to VoiceOver. The keyboard still hides the dock, and Done restores access without saving drafts. Wallet and recurring empty screens scroll with large text. Category colour choices wrap into grids with at least 44-point tap targets and named/selected choices, and category previews use adaptive tinted backgrounds. Card backgrounds, text, borders and status colours use semantic SwiftUI colours for Light/Dark appearance. No stored models, backup format, balances, currencies or save routines changed in this update.

### Check the combined update on an iPhone

1. On Budgets, browse Current/Upcoming/Past/All, including an empty period. Check period counts and create a budget from the empty state. Open a saved recurring budget and follow Previous/Next; verify only the same series appears.
2. Add matching expenses at 79%, 80%, exactly 100%, and beyond the limit. Compare Overview, the budget card and detail. Remaining/exceeded amounts should agree, percentages above 100% should remain visible, and the bar should be capped. Check EUR and HUF budgets separately and a budget without categories.
3. Select Light and Dark in More → Appearance. Review Overview, all five dock tabs, budgets, categories, recurring payments, currencies, export and backup review. Open add/edit sheets and check backgrounds and labels follow the choice.
4. In iOS Settings → Accessibility → Display & Text Size → Larger Text, enable Larger Accessibility Sizes and choose the largest size. Check long wallet/category/budget names and large HUF amounts. Labels and values should stack; recurring buttons and category colour grids should remain reachable. Scroll each screen and check its final row stays above the dock.
5. Enter a partial transaction or transfer, dismiss the keyboard with Done, switch tabs and return. Confirm the draft persists and no new record is created. Check accessibility labels with VoiceOver, including every dock icon, category choices, Rename and Skip.
6. Run the Xcode tests with an iPhone simulator's software keyboard enabled. The new budget tests cover thresholds/exact amounts, unclamped overspending, boundary-day grouping/order, and series navigation. Added UI tests cover budget tabs/details and a large-text dark-mode navigation/keyboard flow, with a screenshot attachment for visual inspection. Source checks on Linux cannot run these tests or render SwiftUI; device/simulator visual verification is still required.

## Refined transaction list

Transactions now has quick **All / Expenses / Income / Transfers** buttons, a matching row count, and clearer day headers with dates and counts. Signed amounts and the two currency amounts of each transfer remain visible. Tap a row to open its existing detail/edit screen. No balances or stored records are changed by browsing, searching, or filtering.

Search matches notes, wallet names, category/subcategory names, currencies, transaction types, and amounts. It ignores case and accents (for example, `kave` matches `Kávé`). Multiple words can match different fields of the same row: `rent bank EUR` requires all three terms. Decimal commas and points work for amount searches. Searches and filters combine, and remain set when switching tabs during this session.

**Filters** opens a separate draft with menu dropdowns for type, wallet, category, and date period. **Apply** updates the list; **Cancel** or swiping the sheet away leaves it unchanged. Date periods include Any Time, Last 7 Days (today plus the previous six days), This Month, Last Month, and an inclusive Custom Range. Calendar months include any recorded future-dated entries within that month. Custom ranges allow future dates; moving From beyond To moves To along. Date boundaries use the local calendar, including daylight-saving days.

A selected wallet matches both incoming and outgoing transfers. Transfers have no category, so choosing Transfers clears the category filter and disables its picker. Selecting a category restricts results to matching income/expenses. Wallet, category, and date chips can each be tapped to remove that filter. **Reset** clears filters while retaining the search; **Clear Search** removes only the query. Controls remain available above the empty/no-results state. Deleted wallets/categories are removed from the active filter selection without altering historical rows or transfer currency snapshots.

### Check the transaction list

1. Add an expense, an income payment, and a transfer with different notes. Search for one note and switch between the four type buttons. Check the count and that Reset keeps your search.
2. Search an accented note without accents, then combine a note word with a wallet name or currency. Check a fractional amount with both decimal separators. Use Clear Search when no rows match.
3. Open Filters, change wallet/category/date, then Cancel or swipe away; the list should keep its previous selection. Reopen and Apply; verify chips appear and can be removed individually.
4. Filter a transfer by its source wallet and then by its destination. Both should match. Select a category and check transfers disappear; choose Transfers and check the category resets.
5. Try each date preset and a single-day custom range. Check transactions late on the last selected day are included, and the following day is excluded. Move From after To and check To follows it.
6. Check empty data and no matching results, long names, accessibility text sizes, and Light/Dark appearance. Dismiss the keyboard and verify the dock remains accessible. Open a matching row and verify editing/navigation still work.

Five new unit tests cover combined filters, category identity, both transfer wallets, accent/multi-field/amount search, inclusive and daylight-saving date boundaries, calendar presets, missing relationships, and stable date grouping. One new UI test covers type switching, no results, accent search, Apply/Cancel, removable chips, Reset, and navigation to a result. Run these in Xcode; Linux source checks do not execute Apple UI or SwiftData code.

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

## Overview and navigation

The app opens on **Add Transaction**. The dock is **Overview · Transactions · + · Wallets · More**, with a larger central + button that opens the full-page transaction form. Budgets are available under **More → Budgets** and from **Overview → Current budgets → See all**. Switching tabs keeps your unfinished transaction for the current app session. A fresh app launch starts on Add Transaction.

Overview shows this month's spending, income and net cash flow, wallet balances, recent transactions, spending by category, current budget progress, and the next active recurring bills. Currencies have separate spending totals. Wallet balances include transfers, budget spending matches its categories/currency/date range, and bills use their postponed dates when applicable. Overdue bills appear first; paused bills are excluded.

Tap a wallet, transaction, transfer, budget, or bill to open its existing detail screen, or use **See all** to open the full list. Recurring monthly budgets catch up on Overview as well as on Budgets.

On **Add Transaction**, choose **Expense** or **Income** at the top. Income needs a positive amount and a wallet; use the source/note field for Salary, Refund, or another description. Income does not require a spending category or sufficient existing funds. Expenses retain their category and balance-limit checks. Switch tabs and return using **+** to resume the unfinished transaction, including its type, amount, note, date and selections. The keyboard's **Done** button dismisses it without saving. The dock hides while the keyboard is open and returns when it is dismissed. Successful saves clear the amount/note for the next transaction and keep you on the Add page.

## Recent transactions and spending by category

- **Recent transactions** shows the latest five saved income, expense, and transfer entries across all wallets, newest first. It includes older months when there are fewer recent entries, while excluding future dates. Income uses a green plus amount; transfers show both outgoing and incoming amounts in blue.
- Tap a row to open its existing detail screen for editing or deletion. **See all** opens the Transactions tab with its search and filters.
- **Spending by category** groups this month's expenses by category and currency. Each currency has its own total, amounts, and percentage bars. Categories appear from highest spending to lowest. Subcategories contribute to their parent category; categories with identical names remain distinct.
- Expenses with no category, including those whose category was deleted, appear as **Uncategorized**. Expenses with no wallet are excluded, with an explanatory count. Income and transfers never contribute to the breakdown.
- Empty states appear when there is no activity or no monthly spending. Changes made from a transaction detail screen update Overview through the existing SwiftData queries.

### Check the updated Overview

1. Add two HUF expenses of 3,000 and 2,000 to Food, and 1,000 to Transport. Food should show 5,000 HUF (83%) and Transport 1,000 HUF (17%) when these are the only expenses this month.
2. Add an EUR expense and verify it gets a separate currency card. Add income and a transfer; both should appear in recent transactions without increasing category spending.
3. Tap an expense, an income, and a transfer from Overview and check their detail screens. Edit an expense amount and return to Overview to verify the category total updates. Delete a transaction and check it disappears from recent transactions.
4. Use **Recent transactions → See all** to open Transactions. Check empty Overview states and the layout with large text, long category names, and long notes.

## Income support

- Wallet balance is starting balance + income − expenses − outgoing transfers + incoming transfers. All wallet, expense, bill-payment, and transfer screens share the same calculation.
- Overview shows income and net cash flow (income minus expenses) separately for each currency. Transfers do not count as income or spending.
- Income appears with a green plus amount and an income label in Transactions, and a green plus amount in wallet history. Searching for `income` or `expense` matches the transaction type as well as existing search fields.
- Open an income transaction to edit its amount, date, note, or wallet, or to delete it. Its transaction type stays fixed when editing. Reducing, moving, or deleting income adjusts the affected balances, even if that exposes a negative balance; expense and transfer creation still enforce each wallet's spending limit.
- Income never uses up a category budget. Recurring bill payments continue to create expenses.
- The stored `ExpenseTransaction` model name is retained. The only added stored field is `isIncome: Bool = false`, intended for a lightweight migration that treats previous records as expenses. Verify this upgrade against existing on-device data before relying on it; the migration could not be run in this environment.
- Saving a new transaction confirms only after `modelContext.save()` succeeds. If it fails, the draft remains available to retry.

### Try this in Xcode

1. Run this version over your existing installation and confirm old expenses, wallets, budgets, and recurring bills still load.
2. On **Add Transaction → Income**, save Salary of **685,000 HUF** into a wallet. Its balance and Overview income should increase by 685,000 HUF, while spending and budgets stay the same.
3. Record an expense of **5,000 HUF** from that wallet. With just these two transactions this month, net cash flow should be **680,000 HUF**.
4. Check income can be saved into an empty wallet without selecting a category. Check income works with an overdrawn wallet and a credit-card wallet as well.
5. Edit the income amount and then move it to another wallet of the same currency; verify both balances. Delete it and verify that it no longer appears in Overview income or wallet history.
6. Add income in EUR as well as HUF and check each currency stays separate. Add a transfer and verify it affects wallet balances without changing cash flow.
7. Switch tabs with an unfinished income, then return using +; type, amount, and note should be preserved. Restart the app after saving and confirm the income still exists.

## Refined transactions and recurring payments

Add Transaction and transaction editing share a large amount field, wallet menus with icons, and category dropdowns with icons. Subcategories remain optional. Expense/Income choices have direction icons, income keeps its source/note field, and the primary Add/Save action is highlighted in the navigation bar. A fresh installation can create its first wallet directly from Add Transaction. Transaction and recurring-payment rows show readable category icons, separate amounts/currencies, wallet details, and clear dates/status. At accessibility text sizes, amounts move below the description. The dock occupies its own layout space below the tab pages, so final form/list rows can scroll fully above it; the dock hides while the keyboard is open.

New/Edit Recurring Payment uses the same amount, wallet, category, and note controls, with a payment name and repeat schedule. Name-field Next focuses the amount; note-field Done/Return dismisses the keyboard. Every transaction and recurring payment amount keyboard has **Done**, and dragging the form dismisses it. Dismissal preserves entries and never saves. Cancel in an editor discards changes, and starting Edit again reloads the saved values. Positive amounts use the same strict decimal parser as wallet/budget forms; partial numbers such as `12abc`, zero, negatives, and ambiguous separators cannot be saved.

Transaction additions/edits, recurring payment creation/edits, and confirmation now save explicitly. A failed save keeps the form and draft available, restores the previous records, and shows an error. Existing pending changes are saved before the form mutation; autosave is paused during that mutation and restored afterward. New related models are constructed within that protected save. The transaction's income/expense type stays fixed while editing. Expense limits include transfers and exclude the expense's original amount when validating its edit; income does not require available spending funds.

Creating or editing a recurring payment does not spend money or require the future amount to be available today. Confirm Payment checks the wallet's available funds/credit, accepts an actual amount/date, and commits the expense and schedule advance together. Its initial amount uses canonical decimal text, independent of the device's display separators. Confirmation/Skip advance from the original scheduled date, keeping the existing weekly/monthly/quarterly/half-year/yearly rules. Postponements clear after confirmation/skip; editing the scheduled day clears a postponement, while changing only other fields keeps it. Pause, Resume, Postpone, Skip, Delete, and Revert also save explicitly and roll back on failure. Deleting a recurring payment preserves completed history; reverting a linked transaction restores its previous scheduled/postponed state only after saving succeeds. Due and postponed rows now open their detail page as well as offering quick actions.

### Check transactions and recurring payments

1. With a funded wallet, add an expense and income. Check the larger amount field, category dropdowns, subcategories, and Add action in Light/Dark appearance and with large text. Switch tabs with a draft and return; fields should remain.
2. Try `1 000,50`, `1000.50`, `0`, `-5`, and `12abc`. Valid positive amounts should save exactly; invalid amounts should disable Add/Save/Confirm and show a message. Check a wallet with transfers and a credit/overdraft limit.
3. Edit a transaction's amount, note, date, wallet, and category. Use Done/Return and drag dismissal without saving. Cancel, reopen Edit, and verify its prior values. Save, restart, and verify balances and records persist.
4. Create a recurring payment with a positive amount, name, wallet, category, and schedule. Check Next/Done/Return. Cancel an edit, then save a separate edit. With insufficient current funds, creating the schedule should still work while confirming payment remains disabled.
5. Confirm a due/postponed bill with a different actual amount. Check one expense appears, the balance updates, and the next date follows the original schedule. Cancel confirmation and verify no expense or date change. Confirm again from the details page.
6. Postpone using quick choices and Choose Date, skip, pause/resume, revert a completed payment, and delete a recurring payment. Verify the intended date/status/balance/history after each action and after restarting. Completed history should remain when the schedule is deleted.
7. Run the injected-failure unit tests in Xcode. They check rollback/retry, exact amounts, prior pending changes, transaction wallet moves, retained postponements/history, confirmation and reversion as a single save, and failed deletions/controls. The two additional UI tests exercise creation/editing/confirmation, keyboard controls, validation, cancellation, saved form values, and the last balance row remaining above the dock.

## Refined wallet transfers

Open a wallet and choose **Transfer Money**. The From/To dropdowns show wallet names, icons and currencies; the source starts as the wallet you opened. The destination list excludes that wallet. Amounts are larger, with separate Sent/Received values and a live balance preview. The main Transfer/Save action is highlighted in the navigation bar. The existing dock spacing and category dropdowns are retained.

Same-currency transfers use the sent amount for both sides automatically. For different currencies, enter the exact amount received in the destination currency. No exchange rate is fetched or applied. The sent amount must fit the source wallet's available balance, including income, expenses, earlier transfers, and credit/overdraft limits. Positive amounts use the same strict parser as the other forms: decimal point or comma and properly grouped spaces are accepted; zero, negatives, partial numbers and ambiguous separators disable saving.

Use **Done** above either numeric keyboard, drag the form to dismiss, or use the note's Done/Return key. Cross-currency forms also have **Next** from Sent to Received. These controls preserve entries and never save. Changing the source clears both amount fields; changing the destination clears its received amount so a prior currency's amount cannot carry across. Cancel closes a new form without creating a record. In an editor, Cancel discards changes and returns to the saved transfer; reopening Edit reloads its saved values.

Creation, editing and deletion now save explicitly. Failed saves leave the form and entries available, roll back the attempted changes, and show an error. Both sides are committed together. Editing checks available funds with the original transfer removed from the calculation, keeps the original wallets/currency snapshots, and previews the replacement amounts. Stored records, creation dates, missing historical wallet relationships and currency codes remain intact. Successful deletion restores the corresponding balances in the remaining wallets.

### Check transfers on your iPhone

1. Create two wallets in the same currency, fund the source, and transfer `12.25`. Check both amounts match, balances change by opposite amounts, and a transfer appears in Transactions. Restart and verify it persists.
2. Transfer from EUR to HUF with separate sent/received amounts. Check Next focuses Received, Done/Return and dragging dismiss the keyboard without saving, and each amount retains its own currency. Check Light/Dark appearance, long wallet names and large text.
3. Try zero, a negative or malformed amount, an amount above available funds, and an invalid received amount for a currency change. Saving should be disabled with a clear message. Check a source with income, previous transfers, and an overdraft/credit limit.
4. Edit a transfer's amount, date and note, then Cancel and reopen Edit. Its saved values should return. Save a valid change near the available limit; the original amount should be accounted for and both balances should update once. The source/destination wallets stay fixed during editing.
5. Cancel a new transfer and verify no row or balance change. Delete a saved transfer and verify both balances are restored. Check transfers do not count as spending, income or category-budget usage.
6. Run the five added unit tests in Xcode for exact amounts, same-wallet/invalid-input rejection, cross-currency save failure/retry, edits and original-amount limits, overdraft limits, failed deletion, and missing-wallet currency snapshots. Two added UI tests cover creation/editing/cancellation and same-/different-currency keyboard flows. Run the currency UI test with EUR and HUF enabled (the defaults).

## Refined wallet and budget forms

New/Edit Wallet and New/Edit Budget now share consistent form layouts, live previews, labeled amounts, inline validation, and navigation-bar **Create** or **Save** actions. Wallet appearance has one section with readable icon names and color swatches. Previews show a wallet's starting balance or a budget's limit; they do not change records until saved. The inactive General row has been removed from More, and add-wallet/add-budget buttons have explicit accessibility labels.

Each form has **Done** above the keyboard and interactive keyboard dismissal by dragging the form. Done preserves typed fields and does not save or close the form. Name-field Next moves to the amount field. Cancel discards the form's changes without changing the wallet or budget record.

Amounts accept a decimal point or comma, optional leading sign where applicable, and properly grouped spaces (including nonbreaking spaces) for thousands. For example, `1 000,50` and `1000.50` both represent 1000.50. Inputs such as `12abc`, `12 34`, mixed decimal/grouping separators, nonfinite values, or values that would silently lose decimal precision are rejected. Wallet starting balance accepts zero or negative values as before; budget totals and credit/overdraft limits must be greater than zero. A budget's end date must be on or after its start date. Moving the start past the end also moves the end to that day.

Create and Save dismiss only after explicit persistence succeeds. If saving fails, the form stays open with its typed entries and displays an error. The pending form mutation is rolled back before autosave resumes, so a failed attempt cannot later silently persist or create duplicates. Existing pending changes are flushed before the form mutation. Wallet currency remains fixed after creation. Editing recurring budgets still offers This Budget Only or This & Future Budgets; past periods, other series, category choices, and future periods' dates are retained.

### Check the refined forms

1. Start a wallet and enter its name, starting balance, and currency. Check the live preview, friendly icon choices, and color swatches in both Light and Dark appearance. Check long names and larger accessibility text.
2. Use Done above each keyboard, then drag the form to dismiss it. Values should remain filled and no record should be created. Create from the navigation bar, restart the app, and verify the wallet persists.
3. Try `1 000,50`, `1000.50`, zero, and a negative starting balance. Try `12abc`, `12 34`, or `1.000,50`; invalid input should show an inline message and disable Create/Save.
4. Select Credit Card, check that negative balances are enabled, and enter a positive credit limit. Change to another wallet type and check its balance-rule choices. Edit an existing wallet and Cancel; its prior name/balance/style should remain.
5. Create and edit a budget. Zero or an invalid amount should disable saving. Move the start date beyond the end date and check the end follows it. Create/Save should work once the name, amount and period are valid.
6. Edit a recurring series using each scope. This Budget Only should retain later periods' settings. This & Future Budgets should update their name, amount, currency and recurrence while keeping their dates and categories. Earlier periods should remain unchanged.
7. Saving failures are covered by injected-failure unit tests; run the test suite in Xcode to check rollback, retained drafts, and retry behavior. Check the wallet/budget keyboard UI test with the software keyboard enabled.

## Currency management

Open **More → Currencies** to see your **Added Currencies**, each with an on/off toggle. Tap **Other Currencies** to open the full searchable list, tick the currencies you want in your list, then choose **Done**. Cancel or swipe down leaves the list unchanged. The available list uses the device's currency catalog, with localized names. HUF, EUR, GBP, and USD remain enabled initially, with HUF as the default. Settings are saved immediately and persist after restarting the app.

**Default Currency** controls the initial selection in new wallet and budget forms. New wallets show only enabled currencies. **Manage Currencies** in the new-wallet form opens the same settings without discarding the form. Switching a currency off keeps its row visible so you can turn it back on. Switching off the default selects the first remaining enabled currency; the final enabled currency cannot be switched off. In Other Currencies, unticking a currency removes it from Added Currencies when you choose Done. Newly added currencies start enabled; previously added currencies keep their switch setting. Done requires at least one selected currency.

Existing wallets, transfers, transactions, and budgets keep their currencies and amounts when a currency is hidden. Wallet currency remains fixed after creation. Budget pickers include enabled currencies plus currencies already used by wallets/budgets, and retain an existing budget's selected currency. Totals remain separate by currency; enabling a currency does not add conversion rates or convert balances.

New backups use format version 2 and include the added list, enabled currencies, and default. Earlier version 2 backups/settings without an added list use their enabled currencies as the initial added list. Restore previews show both preferences and apply them after the data save succeeds. Version 1 backups from the previous release remain supported and leave the current currency settings intact. Recovery copies also include the current currency preferences.

### Check currencies

1. Open Currencies → Other Currencies, search `JPY`, tick it, and choose Done. JPY should appear under Added Currencies with its switch on. Select JPY as the default. Start a new wallet; JPY should be selected and available. Save a sample wallet and check its balance/currency on Overview and Wallets.
2. Start a new budget and check JPY is selected. Create a JPY expense and check it contributes only to JPY spending/budgets.
3. Switch JPY off while its wallet exists. Its row should remain visible with its switch off, and turning it on again should work. A fresh wallet form should omit JPY and use the new default; the existing wallet, its history, and its budgets should retain JPY. Budget pickers should still offer it.
4. Leave only one enabled currency and check its toggle is disabled. Re-enable other currencies, restart the app, and verify the added list, off switches, and default persist. Open Other Currencies and change some ticks, then Cancel; the main list should not change.
5. Open Manage Currencies from a partially filled new-wallet form. Change a currency selection, go back, and check the wallet name/balance remain filled and its currency selection remains available.
6. Save a backup with an added currency switched off, change the added list and enabled currencies/default, then restore it. Check the backed-up list and switch settings return. Restore an older version 1 backup and check the current currency settings remain unchanged.

## Appearance

Open **More → Appearance** and choose **System**, **Light**, or **Dark**. System follows the device’s current appearance; Light and Dark override it for this app. The choice applies immediately, is shown beside Appearance in More, and is retained after restarting the app. The default is System.

### Check appearance

1. Select Dark and check Overview, Transactions, Wallets, Budgets, and their detail screens.
2. Open Add Transaction and another sheet (such as Create Wallet), and check that the selected theme carries through.
3. Select Light and repeat. Restart the app and confirm Light remains selected.
4. Select System, then change the simulator/device appearance; the app should follow it. Confirm the More row and selected checkmark match the choice.

## Full backup and restore

Open **More → Backup & Restore → Save Backup** to save a versioned JSON file using the native file picker. Empty installations can also be backed up. The backup includes every wallet and its starting balance/overdraft settings, income and expenses, both sides of transfers, categories and subcategories, budgets and recurring budget series, recurring bills and payment history links, creation dates, notes, the selected appearance, and currency preferences. Amounts use canonical decimal strings to retain exact precision; dates use JSON numeric seconds since Apple's reference date. Existing deleted relationships remain missing, while transfers retain their saved currency codes.

**Choose Backup to Restore** reads and validates the file, then shows its creation date, appearance, currency preferences when included, and record counts. Review it and choose **Restore This Backup → Replace & Restore**. Canceling either review or confirmation leaves the current data unchanged. Restoration replaces the complete dataset rather than merging it; restoring the same file twice does not duplicate records. An empty backup explicitly warns that restoring it clears the current data.

Before replacement, the app saves a complete recovery copy of the current data. If that copy cannot be written, restoration does not proceed. After a successful restore, the app returns to Add Transaction, reloads the tab hierarchy, clears unfinished transaction drafts, and applies the backed-up appearance and included currency preferences. Recurring budgets continue their usual automatic catch-up behavior when Overview or Budgets opens. **More → Backup & Restore → Before Last Restore** lets you save or review the recovery copy. Restoring it follows the same review/confirmation flow and keeps the dataset it replaces as the next recovery copy. Save recovery copies you want to keep; the next restore attempt replaces the internal copy.

The importer rejects unrelated JSON/CSV files, unsupported versions, incomplete records, duplicate identifiers, missing record references, invalid dates, and invalid or imprecise amounts. Files are limited to 32 MB and 100,000 records. All deletes/inserts are committed in a single model-context save with autosave temporarily disabled; failure rolls back the pending replacement. Appearance changes only after that save succeeds. This restores app records, appearance, and included currency preferences, not device signing settings or permissions.

### Check backup and restoration

1. With sample wallets in EUR and HUF, add income, an expense with a subcategory, a cross-currency transfer, a recurring budget, and a postponed/paused recurring bill. Confirm a bill payment too. Choose Dark appearance, save a backup, and note the balances.
2. Change an amount, create an extra wallet, and select Light. Choose the saved backup and check its preview counts/date. Cancel review, then reopen it and cancel the replacement confirmation; the edited data and Light appearance should remain.
3. Restore the saved backup. The extra wallet should disappear, the original amounts and balances should return, and Dark should apply. Open the paid bill transaction and check its recurring-payment link. Restart the app and verify everything remains.
4. Restore the same file again and check that no records duplicate. Save the recovery copy before further restoration if you want to preserve it.
5. Review the recovery copy and restore it to return to the dataset immediately before your most recent restore. Check the preview and restored balances each time.
6. Try a CSV file or unrelated JSON file; it should not be accepted as a backup. Create a backup from an empty installation and verify its restore review clearly states that it removes current data.
7. Save using the Files picker, cancel it, and try again. Verify saving/canceling never changes balances or records. Test existing on-device data as well as a fresh installation.

## CSV export

Open **More → Export Data**. Choose all saved transactions or an inclusive date range, and whether to include wallet transfers. **Save CSV** opens the native file picker. On iPhone and iPad, **Share CSV** opens the native share sheet. Exports with no matching rows are disabled.

Choose **Comma** for comma-separated columns and decimal points, or **Semicolon** for semicolon-separated columns and decimal commas (commonly used in Hungarian Excel). If Excel puts everything in one column, use the other format or import the CSV with the matching column and decimal separators.

The CSV includes Date, Type, Wallet, Amount, Currency, Category, Subcategory, Note, Destination Wallet, Destination Amount, Destination Currency, and Recurring Payment. Rows are chronological. Dates are ISO 8601 timestamps in UTC; date-range selection uses the device's local calendar and includes the entire final day. Income is positive and expenses are negative. Each transfer appears once: the source amount is negative and the destination amount is positive, with both currencies retained. Missing names or relationships use empty cells.

Amounts have no currency symbols or thousands separators. UTF-8 with a BOM preserves Hungarian accents in Excel. Quotes and multiline notes are escaped, and formula-like names/notes are exported as literal spreadsheet text. CSV is a transaction report; it does not include starting balances, budget definitions, or upcoming unpaid bills, and it cannot restore the complete app database.

### Check CSV saving and sharing

1. Export a mixture of income, expenses, and a transfer. Open the file in Excel and check amounts, currency columns, and both sides of the single transfer row.
2. Try both separator formats. Check a fractional EUR amount, an accented wallet/category name, and a note containing a comma, quotation marks, and a newline.
3. Export a date range and check transactions on the final day are included. Turn off transfers and check the row count and file both exclude them.
4. Cancel the file picker, then export again. On iPhone/iPad, share the file and return to the app. Verify no transactions or balances changed.
5. Check an empty date range disables Save/Share and displays its empty state.

## If Xcode reports undefined symbols after replacing the project

If the linker reports missing `ExpenseTransaction.isIncome`, its new initializer, or `Wallet.balance(including:)`, first choose **Product → Clean Build Folder** (Shift–Command–K), then build again (Command–B). This clears old compiled model files that can remain after replacing source files. The updated ZIP gives app sources fresh timestamps as well.

If it persists, close Xcode, extract this ZIP into a new folder instead of merging it with your old project, and open the included `Budgeting App.xcodeproj`. Build the **Budgeting App** scheme again. A build has not been verified on macOS in this environment.

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

The scheme includes fifty-nine unit tests covering wallet balances, overdraft limits, recurring-payment rescheduling, paused payments, monthly totals by currency, transfer amounts, budget date/category/currency matching, bill ordering, and recurring-budget catch-up without duplicate pending periods. Income tests also cover decimal balances with transfers, monthly income/cash flow, spending/budget exclusions, persistent edits and wallet moves, deletion, and store reopening. Dashboard tests also cover category identity and currency separation, subcategory aggregation, excluded dates/income, missing categories/wallets, updates, combined recent activity, limits, and stable ordering. Backup tests cover complete graph/decimal round trips, malformed or oversized files, unsupported versions, missing/duplicate references, rollback after a failed commit, repeated and empty restoration, persistent store reopening, currency-preference round trips, version 1 compatibility, and invalid currency settings. Transfer form tests cover exact signed balance impacts, cross-currency amounts, protected saves, rollback/retry, fixed wallets/currencies, balance and overdraft limits, deletion, and missing-wallet history. Transaction/recurring form tests cover protected creations, edits, wallet moves, confirmation/revert, pause/postpone/skip, deletion with preserved history, exact amounts and failure/retry. Form tests also cover strict full-input decimal parsing, grouped regional amounts, precision-loss rejection, explicit saves, preserved prior changes, rollback/retry for creations and series edits, fixed wallet currency, and recurring-period scope. CSV tests cover signed amounts, transfer currencies and exclusions, metadata, Unicode/escaping, regional separators, inclusive dates, missing relationships, literal text handling, and stable ordering. Fifteen UI tests cover the Add Transaction landing page, the central dock, Overview and More/Budgets navigation, its category and recent sections, reopening expense and income drafts, keyboard dismissal, export options/empty states, backup navigation/actions, wallet/budget form keyboard dismissal and validation, transaction/recurring creation, editing, confirmation and cancellation, and same-/different-currency transfer creation/editing, Next/Done/Return, validation and cancellation. Run the UI tests on an iPhone simulator with the software keyboard enabled, where the dock is visible after dismissing the keyboard. Test sources belong only to their test targets; app sources and assets belong only to the app target. `Info.plist` is processed as build configuration, not copied as a resource.

On Add Transaction, use **Done** above the keyboard or drag the form to dismiss it. The note field's Done/Return key also dismisses the keyboard. Dismissing preserves the entered amount and note. Check this with no wallet configured as well as with a valid expense draft, and verify that you can open another tab afterward without creating a transaction.

Check Overview with no data, with wallets in multiple currencies, with incoming/outgoing transfers, with an overspent budget, and with overdue/postponed/paused bills. Confirm that saving an expense refreshes the spending and budget cards. Leave an unfinished expense by switching tabs, then return using + to verify that its draft remains.

For a physical device or distribution, configure your own signing team in Xcode. Build and test commands above still need validation on macOS; Linux checks only establish project structure and file-reference integrity.
