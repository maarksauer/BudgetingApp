import SwiftUI
import SwiftData

struct RecurringPaymentsView: View {

    @Query(
        sort: \RecurringPayment.scheduledPaymentDate
    )
    private var payments: [RecurringPayment]

    @State private var showingCreatePayment = false

    @State private var paymentToConfirm: RecurringPayment?
    @State private var paymentToPostpone: RecurringPayment?
    @State private var paymentToSkip: RecurringPayment?

    @State private var showingCustomPostponeDate = false
    @State private var customPostponeDate = Date()

    var body: some View {

        Group {

            if payments.isEmpty {

                emptyState

            } else {

                List {

                    if !duePayments.isEmpty {

                        Section("Due") {

                            ForEach(
                                duePayments
                            ) { payment in

                                actionablePaymentRow(
                                    payment
                                )
                            }
                        }
                    }

                    if !postponedPayments.isEmpty {

                        Section("Postponed") {

                            ForEach(
                                postponedPayments
                            ) { payment in

                                actionablePaymentRow(
                                    payment
                                )
                            }
                        }
                    }

                    if !upcomingPayments.isEmpty {

                        Section("Upcoming") {

                            ForEach(
                                upcomingPayments
                            ) { payment in

                                NavigationLink {

                                    RecurringPaymentDetailView(
                                        payment: payment
                                    )

                                } label: {

                                    recurringPaymentRow(
                                        payment
                                    )
                                }
                            }
                        }
                    }

                    if !pausedPayments.isEmpty {

                        Section("Paused") {

                            ForEach(
                                pausedPayments
                            ) { payment in

                                NavigationLink {

                                    RecurringPaymentDetailView(
                                        payment: payment
                                    )

                                } label: {

                                    recurringPaymentRow(
                                        payment
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        .navigationTitle(
            "Recurring Payments"
        )

        .toolbar {

            ToolbarItem(
                placement: .primaryAction
            ) {

                Button {

                    showingCreatePayment = true

                } label: {

                    Image(
                        systemName: "plus"
                    )
                }
            }
        }

        .sheet(
            isPresented:
                $showingCreatePayment
        ) {

            CreateRecurringPaymentView()
        }

        .sheet(
            item:
                $paymentToConfirm
        ) { payment in

            ConfirmRecurringPaymentView(
                payment: payment
            )
        }

        // MARK: - Postpone Options

        .confirmationDialog(
            "Postpone Payment",
            isPresented:
                Binding(
                    get: {

                        paymentToPostpone != nil
                        &&
                        !showingCustomPostponeDate
                    },

                    set: { newValue in

                        if !newValue &&
                            !showingCustomPostponeDate {

                            paymentToPostpone = nil
                        }
                    }
                ),
            titleVisibility:
                .visible
        ) {

            Button(
                "1 Day"
            ) {

                postponeSelectedPayment(
                    byDays: 1
                )
            }

            Button(
                "3 Days"
            ) {

                postponeSelectedPayment(
                    byDays: 3
                )
            }

            Button(
                "1 Week"
            ) {

                postponeSelectedPayment(
                    byDays: 7
                )
            }

            Button(
                "2 Weeks"
            ) {

                postponeSelectedPayment(
                    byDays: 14
                )
            }

            Button(
                "Choose Date…"
            ) {

                prepareCustomPostponeDate()
            }

            Button(
                "Cancel",
                role: .cancel
            ) {

                paymentToPostpone = nil
            }

        } message: {

            Text(
                "Choose how long to postpone this payment."
            )
        }

        // MARK: - Custom Postpone Date

        .sheet(
            isPresented:
                $showingCustomPostponeDate,
            onDismiss: {

                if paymentToPostpone != nil {

                    paymentToPostpone = nil
                }
            }
        ) {

            NavigationStack {

                Form {

                    Section(
                        "Postpone Until"
                    ) {

                        DatePicker(
                            "Date",
                            selection:
                                $customPostponeDate,
                            in:
                                Date()...,
                            displayedComponents:
                                .date
                        )
                    }

                    Section {

                        Text(
                            "This only changes when the current payment is due. The normal recurring schedule will stay unchanged."
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                .navigationTitle(
                    "Choose Date"
                )

                .navigationBarTitleDisplayMode(
                    .inline
                )

                .toolbar {

                    ToolbarItem(
                        placement:
                            .cancellationAction
                    ) {

                        Button(
                            "Cancel"
                        ) {

                            paymentToPostpone =
                                nil

                            showingCustomPostponeDate =
                                false
                        }
                    }

                    ToolbarItem(
                        placement:
                            .confirmationAction
                    ) {

                        Button(
                            "Postpone"
                        ) {

                            applyCustomPostponeDate()
                        }
                    }
                }
            }
        }

        // MARK: - Skip

        .alert(
            "Skip This Payment?",
            isPresented:
                Binding(
                    get: {

                        paymentToSkip != nil
                    },

                    set: { newValue in

                        if !newValue {

                            paymentToSkip = nil
                        }
                    }
                )
        ) {

            Button(
                "Cancel",
                role: .cancel
            ) {

                paymentToSkip = nil
            }

            Button(
                "Skip",
                role: .destructive
            ) {

                skipSelectedPayment()
            }

        } message: {

            Text(
                "No transaction will be created. The payment will move to its next scheduled occurrence."
            )
        }
    }

    // MARK: - Payment Groups

    private var duePayments: [RecurringPayment] {

        payments
            .filter {

                $0.isActive
                &&
                $0.isDue
            }
            .sorted {

                $0.nextPaymentDate
                <
                $1.nextPaymentDate
            }
    }

    private var postponedPayments: [RecurringPayment] {

        payments
            .filter {

                $0.isActive
                &&
                $0.isPostponed
                &&
                !$0.isDue
            }
            .sorted {

                $0.nextPaymentDate
                <
                $1.nextPaymentDate
            }
    }

    private var upcomingPayments: [RecurringPayment] {

        payments
            .filter {

                $0.isActive
                &&
                !$0.isDue
                &&
                !$0.isPostponed
            }
            .sorted {

                $0.nextPaymentDate
                <
                $1.nextPaymentDate
            }
    }

    private var pausedPayments: [RecurringPayment] {

        payments
            .filter {

                !$0.isActive
            }
            .sorted {

                $0.nextPaymentDate
                <
                $1.nextPaymentDate
            }
    }

    // MARK: - Actionable Row

    private func actionablePaymentRow(
        _ payment: RecurringPayment
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            recurringPaymentRow(
                payment
            )

            HStack(
                spacing: 10
            ) {

                // PAID

                Button {

                    paymentToConfirm =
                        payment

                } label: {

                    Label(
                        "Paid",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 46
                    )
                    .foregroundStyle(
                        .white
                    )
                    .background(

                        Capsule()
                            .fill(
                                Color.accentColor
                            )
                    )
                }
                .buttonStyle(
                    .plain
                )

                // POSTPONE

                Button {

                    paymentToPostpone =
                        payment

                } label: {

                    Label(
                        "Postpone",
                        systemImage:
                            "clock"
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 46
                    )
                    .foregroundStyle(
                        Color.accentColor
                    )
                    .background(

                        Capsule()
                            .fill(
                                Color.secondary
                                    .opacity(
                                        0.12
                                    )
                            )
                    )
                }
                .buttonStyle(
                    .plain
                )

                // SKIP

                Button(
                    role: .destructive
                ) {

                    paymentToSkip =
                        payment

                } label: {

                    Image(
                        systemName:
                            "forward.end"
                    )
                    .frame(
                        width: 46,
                        height: 46
                    )
                    .foregroundStyle(
                        .red
                    )
                    .background(

                        Circle()
                            .fill(
                                Color.secondary
                                    .opacity(
                                        0.12
                                    )
                            )
                    )
                }
                .buttonStyle(
                    .plain
                )
            }
        }
        .padding(
            .vertical,
            4
        )
    }

    // MARK: - Standard Row

    private func recurringPaymentRow(
        _ payment: RecurringPayment
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(
                        payment.name
                    )
                    .fontWeight(
                        .semibold
                    )

                    Text(
                        payment.frequency
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer()

                statusBadge(
                    payment
                )
            }

            HStack {

                Text(
                    "\(payment.amount.formatted(.number)) \(payment.wallet?.currencyCode ?? "")"
                )
                .fontWeight(
                    .medium
                )

                Spacer()

                Text(
                    paymentDateText(
                        payment
                    )
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    paymentDateColor(
                        payment
                    )
                )
            }

            HStack(
                spacing: 6
            ) {

                if let wallet =
                    payment.wallet {

                    Label(
                        wallet.name,
                        systemImage:
                            "wallet.bifold"
                    )
                }

                if let category =
                    payment.category {

                    Text(
                        "•"
                    )

                    Label(
                        category.name,
                        systemImage:
                            category.icon
                    )
                }
            }
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {

        VStack(
            spacing: 16
        ) {

            Image(
                systemName:
                    "arrow.trianglehead.2.clockwise.rotate.90"
            )
            .font(
                .system(
                    size: 46
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "No Recurring Payments"
            )
            .font(
                .title3
            )
            .fontWeight(
                .semibold
            )

            Text(
                "Create recurring payments for things like subscriptions, rent, insurance, or memberships."
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )

            Button(
                "Create Recurring Payment"
            ) {

                showingCreatePayment =
                    true
            }
            .buttonStyle(
                .borderedProminent
            )
        }
        .padding()
    }

    // MARK: - Status Badge

    private func statusBadge(
        _ payment: RecurringPayment
    ) -> some View {

        Text(
            payment.statusText
        )
        .font(
            .caption
        )
        .fontWeight(
            .semibold
        )
        .padding(
            .horizontal,
            8
        )
        .padding(
            .vertical,
            4
        )
        .background(

            statusColor(
                payment
            )
            .opacity(
                0.15
            )
        )
        .foregroundStyle(

            statusColor(
                payment
            )
        )
        .clipShape(
            Capsule()
        )
    }

    private func statusColor(
        _ payment: RecurringPayment
    ) -> Color {

        if !payment.isActive {

            return .gray
        }

        if payment.isDue {

            return .red
        }

        if payment.isPostponed {

            return .orange
        }

        return .green
    }

    // MARK: - Payment Date Text

    private func paymentDateText(
        _ payment: RecurringPayment
    ) -> String {

        let calendar =
            Calendar.current

        if payment.isPostponed {

            if calendar.isDateInToday(
                payment.nextPaymentDate
            ) {

                return "Postponed until today"
            }

            return
                "Postponed until \(payment.nextPaymentDate.formatted(date: .abbreviated, time: .omitted))"
        }

        if payment.isDue {

            if calendar.isDateInToday(
                payment.nextPaymentDate
            ) {

                return "Due today"
            }

            return
                "Due \(payment.nextPaymentDate.formatted(date: .abbreviated, time: .omitted))"
        }

        return
            payment.nextPaymentDate.formatted(
                date: .abbreviated,
                time: .omitted
            )
    }

    private func paymentDateColor(
        _ payment: RecurringPayment
    ) -> Color {

        if payment.isDue {

            return .red
        }

        if payment.isPostponed {

            return .orange
        }

        return .secondary
    }

    // MARK: - Postpone

    private func postponeSelectedPayment(
        byDays days: Int
    ) {

        guard
            let payment =
                paymentToPostpone
        else {

            return
        }

        let startingDate =
            max(
                payment.nextPaymentDate,
                Date()
            )

        if let newDate =
            Calendar.current.date(
                byAdding:
                    .day,
                value:
                    days,
                to:
                    startingDate
            ) {

            payment.postponedUntil =
                newDate
        }

        paymentToPostpone =
            nil
    }

    // MARK: - Custom Postpone Date

    private func prepareCustomPostponeDate() {

        guard
            let payment =
                paymentToPostpone
        else {

            return
        }

        let tomorrow =
            Calendar.current.date(
                byAdding:
                    .day,
                value:
                    1,
                to:
                    Date()
            )
            ??
            Date()

        customPostponeDate =
            max(
                payment.nextPaymentDate,
                tomorrow
            )

        showingCustomPostponeDate =
            true
    }

    private func applyCustomPostponeDate() {

        guard
            let payment =
                paymentToPostpone
        else {

            showingCustomPostponeDate =
                false

            return
        }

        payment.postponedUntil =
            customPostponeDate

        paymentToPostpone =
            nil

        showingCustomPostponeDate =
            false
    }

    // MARK: - Skip

    private func skipSelectedPayment() {

        guard
            let payment =
                paymentToSkip
        else {

            return
        }

        payment.scheduledPaymentDate =
            nextScheduledDate(
                for:
                    payment,
                from:
                    payment.scheduledPaymentDate
            )

        payment.postponedUntil =
            nil

        paymentToSkip =
            nil
    }

    // MARK: - Next Scheduled Date

    private func nextScheduledDate(
        for payment:
            RecurringPayment,
        from date:
            Date
    ) -> Date {

        let calendar =
            Calendar.current

        switch payment.frequency {

        case "Weekly":

            return calendar.date(
                byAdding:
                    .weekOfYear,
                value:
                    1,
                to:
                    date
            )
            ??
            date

        case "Monthly":

            return calendar.date(
                byAdding:
                    .month,
                value:
                    1,
                to:
                    date
            )
            ??
            date

        case "Every 3 Months":

            return calendar.date(
                byAdding:
                    .month,
                value:
                    3,
                to:
                    date
            )
            ??
            date

        case "Every 6 Months":

            return calendar.date(
                byAdding:
                    .month,
                value:
                    6,
                to:
                    date
            )
            ??
            date

        case "Yearly":

            return calendar.date(
                byAdding:
                    .year,
                value:
                    1,
                to:
                    date
            )
            ??
            date

        default:

            return date
        }
    }
}
