import SwiftUI
import SwiftData

/// Bottom-only rounded shape for wallet-style pack cards.
private let walletCardShape = UnevenRoundedRectangle(
    cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 18, bottomTrailing: 18, topTrailing: 0)
)

private enum WalletCardLayout {
    static let bottomCornerRadius: CGFloat = 18
    static let backLayerInset: CGFloat = 10
    static let backLayerPeek: CGFloat = 4
    static let backLayerFill = Color(red: 0.55, green: 0.42, blue: 0.30)
    static let frontLayerFill = Color(red: 0.62, green: 0.48, blue: 0.36)
    /// Add-pack card: very light grey (opaque), reads as secondary.
    static let addPackFrontFill = Color(white: 0.92)
    static let addPackBackFill = Color(white: 0.86)
    /// Clear plastic pocket: inset from pack edges.
    static let pocketInset: CGFloat = 6
    /// Extra padding above the glass pane to mimic the fold at the top of a real pack.
    static let pocketTopFoldInset: CGFloat = 14
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
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let frontHeight = totalHeight - WalletCardLayout.backLayerPeek
            ZStack(alignment: .top) {
                // Back layer: full rectangle (same shape as pack) so no gap at corners; 8pt visible below front
                walletCardShape
                    .fill(WalletCardLayout.backLayerFill)
                    .frame(maxWidth: .infinity)
                    .frame(height: totalHeight)
                    .padding(.horizontal, WalletCardLayout.backLayerInset)
                    .offset(y: WalletCardLayout.backLayerPeek)

                // Front layer: main card with glass pocket
                ZStack {
                    walletCardShape
                        .fill(WalletCardLayout.frontLayerFill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    RoundedRectangle(cornerRadius: WalletCardLayout.pocketCornerRadius)
                        .fill(.clear)
                        .glassEffect(in: RoundedRectangle(cornerRadius: WalletCardLayout.pocketCornerRadius))
                        .overlay(
                            Text(pack.title)
                                .font(.system(.largeTitle, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.black)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, WalletCardLayout.pocketTopFoldInset)
                        .padding(.horizontal, WalletCardLayout.pocketInset)
                        .padding(.bottom, WalletCardLayout.pocketInset)
                }
                .frame(maxWidth: .infinity)
                .frame(height: frontHeight)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: totalHeight)
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
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let frontHeight = totalHeight - WalletCardLayout.backLayerPeek
            ZStack(alignment: .top) {
                // Back layer: full rectangle (same shape as pack) so no gap at corners
                walletCardShape
                    .fill(WalletCardLayout.addPackBackFill)
                    .frame(maxWidth: .infinity)
                    .frame(height: totalHeight)
                    .padding(.horizontal, WalletCardLayout.backLayerInset)
                    .offset(y: WalletCardLayout.backLayerPeek)

                // Front layer: main card with glass pocket (same as pack cards)
                ZStack {
                    walletCardShape
                        .fill(WalletCardLayout.addPackFrontFill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    RoundedRectangle(cornerRadius: WalletCardLayout.pocketCornerRadius)
                        .fill(.clear)
                        .glassEffect(in: RoundedRectangle(cornerRadius: WalletCardLayout.pocketCornerRadius))
                        .overlay(
                            Image(systemName: "plus")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, WalletCardLayout.pocketTopFoldInset)
                        .padding(.horizontal, WalletCardLayout.pocketInset)
                        .padding(.bottom, WalletCardLayout.pocketInset)
                }
                .frame(maxWidth: .infinity)
                .frame(height: frontHeight)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: totalHeight)
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
