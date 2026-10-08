import SwiftUI
import SwiftData

struct WalletsView: View {

    @Query(
        sort: \Wallet.createdAt
    )
    private var wallets: [Wallet]

    @Query
    private var transfers:
        [WalletTransfer]

    @State private var showingCreateWallet = false

    var body: some View {

        NavigationStack {

            Group {

                if wallets.isEmpty {

                    ScrollView { emptyState }

                } else {

                    List {

                        ForEach(
                            wallets
                        ) { wallet in

                            NavigationLink {

                                WalletDetailView(
                                    wallet: wallet
                                )

                            } label: {

                                walletRow(
                                    wallet
                                )
                            }
                        }
                    }
                }
            }

            .navigationTitle(
                "Wallets"
            )

            .toolbar {

                ToolbarItem(
                    placement:
                        .primaryAction
                ) {

                    Button {

                        showingCreateWallet =
                            true

                    } label: {

                        Image(
                            systemName:
                                "plus"
                        )
                    }
                    .accessibilityLabel("Add Wallet")
                    .accessibilityIdentifier("openCreateWallet")
                }
            }

            .sheet(
                isPresented:
                    $showingCreateWallet
            ) {

                CreateWalletView()
            }
        }
    }

    private var emptyState:
        some View {

        VStack(spacing: 16) {

            Image(
                systemName:
                    "wallet.bifold"
            )
            .font(
                .system(size: 48)
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "No Wallets Yet"
            )
            .font(.title3)
            .fontWeight(
                .semibold
            )

            Text(
                "Create a wallet to start tracking your money."
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )

            Button(
                "Create Wallet"
            ) {

                showingCreateWallet =
                    true
            }
            .buttonStyle(
                .borderedProminent
            )
        }
        .padding()
    }

    private func walletRow(_ wallet: Wallet) -> some View {
        AdaptiveValueRow {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wallet.name).font(.headline)
                    Text(wallet.walletType).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: wallet.icon).foregroundStyle(FormPalette.color(wallet.colorName))
            }
        } trailing: {
            VStack(alignment: .leading, spacing: 4) {
                Text(balance(for: wallet).formatted(.number)).fontWeight(.semibold).monospacedDigit()
                Text(wallet.currencyCode).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func balance(
        for wallet: Wallet
    ) -> Decimal {
        wallet.balance(including: transfers)
    }

    private func colorFromName(
        _ name: String
    ) -> Color {

        switch name {

        case "blue":
            return .blue

        case "green":
            return .green

        case "orange":
            return .orange

        case "purple":
            return .purple

        case "red":
            return .red

        case "pink":
            return .pink

        case "teal":
            return .teal

        case "gray":
            return .gray

        default:
            return .blue
        }
    }
}
