import Foundation
import SwiftData

@MainActor
enum BudgetSchedule {
    static func generateIfNeeded(
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        // Fetch current rows so two screens opening in succession cannot generate
        // duplicate periods while their @Query results are still updating.
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        for budget in missingMonthlyBudgets(from: budgets, through: now, calendar: calendar) {
            context.insert(budget)
        }
    }

    static func missingMonthlyBudgets(
        from budgets: [Budget],
        through now: Date,
        calendar: Calendar = .current
    ) -> [Budget] {
        let today = calendar.startOfDay(for: now)
        let recurring = budgets.filter { $0.isRecurring && $0.recurrenceType == "Monthly" }
        let seriesIDs = Set(recurring.map { $0.seriesID })
        var missing: [Budget] = []

        for seriesID in seriesIDs {
            guard var latest = budgets.filter({ $0.seriesID == seriesID })
                .max(by: { $0.startDate < $1.startDate }), latest.isRecurring else {
                continue
            }
            while calendar.startOfDay(for: latest.endDate) < today {
                guard let next = nextMonthlyBudget(from: latest, calendar: calendar) else { break }
                missing.append(next)
                latest = next
            }
        }
        return missing
    }

    private static func nextMonthlyBudget(from budget: Budget, calendar: Calendar) -> Budget? {
        guard let start = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: budget.endDate)
        ), let followingMonth = calendar.date(byAdding: .month, value: 1, to: start),
           let end = calendar.date(byAdding: .day, value: -1, to: followingMonth) else {
            return nil
        }
        let next = Budget(
            name: budget.name,
            totalAmount: budget.totalAmount,
            currencyCode: budget.currencyCode,
            startDate: start,
            endDate: end,
            isRecurring: true,
            recurrenceType: budget.recurrenceType,
            seriesID: budget.seriesID
        )
        next.categories = budget.categories
        return next
    }
}
