import SwiftUI
import SwiftData

struct RecurringPaymentsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @State private var showingSaveError = false
    @State private var showingPostponeError = false
    @State private var saveError = ""


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

        List {
            if payments.isEmpty {
                Section {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }


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
                .accessibilityLabel("Add Recurring Payment")
                .accessibilityIdentifier("openCreateRecurringPayment")
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

        .confirmationDialog("Postpone Payment", isPresented: Binding(
            get: { paymentToPostpone != nil && !showingCustomPostponeDate },
            set: { visible in
                if !visible && !showingCustomPostponeDate { paymentToPostpone = nil }
            }
        ), titleVisibility: .visible) {
            if let payment = paymentToPostpone {
                Button("1 Day") { postponeSelectedPayment(payment, byDays: 1) }
                Button("3 Days") { postponeSelectedPayment(payment, byDays: 3) }
                Button("1 Week") { postponeSelectedPayment(payment, byDays: 7) }
                Button("2 Weeks") { postponeSelectedPayment(payment, byDays: 14) }
                Button("Choose Date…") { prepareCustomPostponeDate(payment) }
            }
            Button("Cancel", role: .cancel) { paymentToPostpone = nil }
        } message: { Text("Choose how long to postpone this payment.") }

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
                                Calendar.current.startOfDay(for: Date())...,
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
                .alert("Couldn’t postpone payment", isPresented: $showingPostponeError) {
                    Button("OK", role: .cancel) { }
                } message: { Text("Your selected date is still here. \(saveError)") }
            }
        }

        .alert("Skip This Payment?", isPresented: Binding(
            get: { paymentToSkip != nil }, set: { visible in if !visible { paymentToSkip = nil } }
        )) {
            Button("Cancel", role: .cancel) { paymentToSkip = nil }
            if let payment = paymentToSkip {
                Button("Skip", role: .destructive) { skipSelectedPayment(payment) }
            }
        } message: { Text("No transaction will be created. The payment will move to its next scheduled occurrence.") }
        .alert("Couldn’t save changes", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please try again. \(saveError)") }
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

    private var actionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
        : AnyLayout(HStackLayout(spacing: 10))
    }

    // MARK: - Actionable Row

    private func actionablePaymentRow(
        _ payment: RecurringPayment
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            NavigationLink { RecurringPaymentDetailView(payment: payment) } label: {
                recurringPaymentRow(payment)
            }
            .accessibilityIdentifier("recurringPayment-\(payment.name)")

            actionLayout {

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
                    .padding(.vertical, 12)
                    .frame(minHeight: 46)
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
                    .padding(.vertical, 12)
                    .frame(minHeight: 46)
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
                .buttonStyle(.plain)
                .accessibilityLabel("Skip \(payment.name)")
            }
        }
        .padding(
            .vertical,
            4
        )
    }

    private func recurringPaymentRow(_ payment: RecurringPayment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TransactionSummaryRow(
                title: payment.name, subtitle: "\(payment.frequency) · \(payment.category?.name ?? "Uncategorized")",
                detail: payment.wallet?.name ?? "Missing wallet",
                symbol: payment.category?.icon ?? "arrow.trianglehead.2.clockwise.rotate.90",
                tint: FormPalette.color(payment.category?.colorName ?? "blue"),
                amount: payment.amount.formatted(.number), currency: payment.wallet?.currencyCode ?? "", secondaryAmount: nil
            )
            AdaptiveValueRow {
                Label(paymentDateText(payment), systemImage: "calendar")
                    .font(.caption).foregroundStyle(paymentDateColor(payment))
            } trailing: {
                statusBadge(payment)
            }
        }
        .padding(.vertical, 4)
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

    private func postponeSelectedPayment(_ payment: RecurringPayment, byDays days: Int) {
        let start = max(payment.nextPaymentDate, Date())
        if let date = Calendar.current.date(byAdding: .day, value: days, to: start) {
            do { try FormStore.postponeRecurringPayment(payment, until: date, context: modelContext) }
            catch { saveError = error.localizedDescription; showingSaveError = true }
        }
        paymentToPostpone = nil
    }

    private func prepareCustomPostponeDate(_ payment: RecurringPayment) {
        paymentToPostpone = payment
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        customPostponeDate = max(payment.nextPaymentDate, tomorrow)
        showingCustomPostponeDate = true
    }

    private func applyCustomPostponeDate() {
        guard let payment = paymentToPostpone else { return }
        do {
            try FormStore.postponeRecurringPayment(payment, until: customPostponeDate, context: modelContext)
            paymentToPostpone = nil; showingCustomPostponeDate = false
        } catch { saveError = error.localizedDescription; showingPostponeError = true }
    }

    private func skipSelectedPayment(_ payment: RecurringPayment) {
        do { try FormStore.skipRecurringPayment(payment, context: modelContext) }
        catch { saveError = error.localizedDescription; showingSaveError = true }
        paymentToSkip = nil
    }
}
