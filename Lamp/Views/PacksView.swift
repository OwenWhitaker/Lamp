import SwiftUI
import SwiftData

/// Bottom-only rounded shape for wallet-style pack cards.
private let walletCardShape = UnevenRoundedRectangle(
    cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 12, bottomTrailing: 12, topTrailing: 0)
)

/// Bottom-only rounded shape for the thin peek strip (smaller radius so it fits).
private let walletPeekShape = UnevenRoundedRectangle(
    cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 8, bottomTrailing: 8, topTrailing: 0)
)

private enum WalletCardLayout {
    static let bottomCornerRadius: CGFloat = 12
    static let backLayerInset: CGFloat = 10
    static let backLayerPeek: CGFloat = 8
    static let backLayerFill = Color(red: 0.55, green: 0.42, blue: 0.30)
    static let frontLayerFill = Color(red: 0.62, green: 0.48, blue: 0.36)
    /// Clear plastic pocket: inset from pack edges. Kept so (bottomCornerRadius - pocketInset) is a visible radius for concentric bottom corners.
    static let pocketInset: CGFloat = 6
    /// Pane corner radius: pack radius minus inset so bottom corners are concentric with pack; same value for all four corners.
    static var pocketCornerRadius: CGFloat { max(0, bottomCornerRadius - pocketInset) }
}

struct PacksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pack.createdAt, order: .reverse) private var packs: [Pack]
    @Binding var path: NavigationPath
    @Binding var showAddPack: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    /// When 2 or fewer packs: full-width thirds. When 3+: 2-column grid.
    private var useThirdsLayout: Bool { packs.count <= 2 }

    var body: some View {
        if useThirdsLayout {
            thirdsLayout
        } else {
            gridLayout
        }
    }

    private var thirdsLayout: some View {
        GeometryReader { geo in
            let thirdHeight = geo.size.height / 3
            let horizontalPadding: CGFloat = 24
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if packs.isEmpty {
                        AddPackCardView(fillHeight: true) { showAddPack = true }
                            .frame(height: thirdHeight)
                            .padding(.horizontal, horizontalPadding)
                    } else {
                        if let first = packs.first {
                            PackCardView(pack: first, fillHeight: true) { path.append(first) }
                                .frame(height: thirdHeight)
                                .padding(.horizontal, horizontalPadding)
                        }
                        if packs.count >= 2, let second = packs.dropFirst().first {
                            PackCardView(pack: second, fillHeight: true) { path.append(second) }
                                .frame(height: thirdHeight)
                                .padding(.horizontal, horizontalPadding)
                        }
                        AddPackCardView(fillHeight: true) { showAddPack = true }
                            .frame(height: thirdHeight)
                            .padding(.horizontal, horizontalPadding)
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    private var gridLayout: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(packs) { pack in
                    PackCardView(pack: pack, fillHeight: false) {
                        path.append(pack)
                    }
                }
                AddPackCardView(fillHeight: false) {
                    showAddPack = true
                }
            }
            .padding()
        }
    }
}

struct PackCardView: View {
    let pack: Pack
    let fillHeight: Bool
    let action: () -> Void

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Front layer: main card with clear plastic pocket taking most of the front
            ZStack {
                walletCardShape
                    .fill(WalletCardLayout.frontLayerFill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Inset liquid glass pane (plastic pocket): all four corners rounded; bottom radii concentric with pack.
                Text(pack.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.18, green: 0.12, blue: 0.08))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassEffect()
                    .clipShape(RoundedRectangle(cornerRadius: WalletCardLayout.pocketCornerRadius))
                    .padding(WalletCardLayout.pocketInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            // Back layer peek: slightly narrower strip with rounded bottom
            walletPeekShape
                .fill(WalletCardLayout.backLayerFill)
                .frame(height: WalletCardLayout.backLayerPeek)
                .padding(.horizontal, WalletCardLayout.backLayerInset)
        }
    }

    var body: some View {
        Button(action: action) {
            Group {
                if fillHeight {
                    cardContent.frame(maxHeight: .infinity)
                } else {
                    cardContent.aspectRatio(3/4, contentMode: .fit)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct AddPackCardView: View {
    let fillHeight: Bool
    let action: () -> Void

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Front layer: main card
            Image(systemName: "plus")
                .font(.largeTitle)
                .foregroundStyle(Color(red: 0.22, green: 0.14, blue: 0.10))
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background(walletCardShape.fill(WalletCardLayout.frontLayerFill))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            // Back layer peek: slightly narrower strip with rounded bottom
            walletPeekShape
                .fill(WalletCardLayout.backLayerFill)
                .frame(height: WalletCardLayout.backLayerPeek)
                .padding(.horizontal, WalletCardLayout.backLayerInset)
        }
    }

    var body: some View {
        Button(action: action) {
            Group {
                if fillHeight {
                    cardContent.frame(maxHeight: .infinity)
                } else {
                    cardContent.aspectRatio(3/4, contentMode: .fit)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        PacksView(path: .constant(NavigationPath()), showAddPack: .constant(false))
            .navigationTitle("My Packs")
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
