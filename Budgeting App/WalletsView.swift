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

                    emptyState

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

    private func walletRow(
        _ wallet: Wallet
    ) -> some View {

        HStack(
            spacing: 14
        ) {

            Image(
                systemName:
                    wallet.icon
            )
            .foregroundStyle(
                colorFromName(
                    wallet.colorName
                )
            )
            .font(.title3)
            .frame(
                width: 42,
                height: 42
            )
            .background(
                colorFromName(
                    wallet.colorName
                )
                .opacity(0.15)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 11
                )
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    wallet.name
                )
                .fontWeight(
                    .medium
                )

                Text(
                    wallet.walletType
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 3
            ) {

                Text(
                    balance(
                        for: wallet
                    ),
                    format: .number
                )
                .fontWeight(
                    .semibold
                )

                Text(
                    wallet.currencyCode
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(
            .vertical,
            4
        )
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
