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

    @State private var packForAction: Pack?
    @State private var showActionDialog = false
    @State private var showRenameSheet = false
    @State private var renameText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    /// When 2 or fewer packs: full-width thirds. When 3+: 2-column grid.
    private var useThirdsLayout: Bool { packs.count <= 2 }

    var body: some View {
        Group {
            if useThirdsLayout {
                thirdsLayout
            } else {
                gridLayout
            }
        }
        .confirmationDialog("Pack", isPresented: $showActionDialog, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let pack = packForAction {
                    modelContext.delete(pack)
                    try? modelContext.save()
                }
                packForAction = nil
            }
            Button("Rename") {
                renameText = packForAction?.title ?? ""
                showRenameSheet = true
            }
            Button("Cancel", role: .cancel) {
                packForAction = nil
            }
        } message: {
            Text(packForAction.map { "\"\($0.title)\"" } ?? "")
        }
        .sheet(isPresented: $showRenameSheet, onDismiss: { packForAction = nil }) {
            NavigationStack {
                Form {
                    TextField("Pack name", text: $renameText)
                }
                .navigationTitle("Rename Pack")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showRenameSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if let pack = packForAction, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                                pack.title = renameText.trimmingCharacters(in: .whitespaces)
                                try? modelContext.save()
                            }
                            showRenameSheet = false
                        }
                        .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var thirdsLayout: some View {
        GeometryReader { geo in
            let verticalPadding: CGFloat = 16
            let horizontalPadding: CGFloat = 24
            let cardSpacing: CGFloat = 20
            let cardCount: CGFloat = packs.isEmpty ? 1 : CGFloat(packs.count + 1)
            let gaps = max(0, cardCount - 1) * cardSpacing
            let availableHeight = geo.size.height - (2 * verticalPadding) - gaps
            let availableWidth = geo.size.width - (2 * horizontalPadding)
            // Lock 2:3 vertical:horizontal — fit both dimensions
            let maxHeightByVertical = availableHeight / cardCount
            let maxHeightByWidth = availableWidth * 2 / 3 // so width = height * 3/2 ≤ availableWidth
            let cardHeight = min(maxHeightByVertical, maxHeightByWidth)
            let cardWidth = cardHeight * 3 / 2
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: cardSpacing) {
                    if packs.isEmpty {
                        AddPackCardView(fillHeight: true) { showAddPack = true }
                            .frame(width: cardWidth, height: cardHeight)
                            .frame(maxWidth: .infinity)
                    } else {
                        if let first = packs.first {
                            PackCardView(pack: first, fillHeight: true, action: { path.append(first) }, onLongPress: {
                                packForAction = first
                                showActionDialog = true
                            })
                                .frame(width: cardWidth, height: cardHeight)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        }
                        if packs.count >= 2, let second = packs.dropFirst().first {
                            PackCardView(pack: second, fillHeight: true, action: { path.append(second) }, onLongPress: {
                                packForAction = second
                                showActionDialog = true
                            })
                                .frame(width: cardWidth, height: cardHeight)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        }
                        AddPackCardView(fillHeight: true) { showAddPack = true }
                            .frame(width: cardWidth, height: cardHeight)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    }
                }
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, horizontalPadding)
            }
        }
    }

    private var gridLayout: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(packs) { pack in
                    PackCardView(pack: pack, fillHeight: false, action: { path.append(pack) }, onLongPress: {
                        packForAction = pack
                        showActionDialog = true
                    })
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
    var onLongPress: (() -> Void)? = nil

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
                                .font(.system(size: min(geo.size.width, geo.size.height) * 0.14, design: .rounded))
                                .minimumScaleFactor(0.6)
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
        Group {
            if fillHeight {
                cardContent.frame(maxHeight: .infinity)
            } else {
                cardContent.aspectRatio(3/2, contentMode: .fit) // 2:3 vertical:horizontal for grid
            }
        }
        .contentShape(.rect)
        .onTapGesture { action() }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress?()
        }
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
                                .font(.system(size: min(geo.size.width, geo.size.height) * 0.2, design: .rounded))
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
                    cardContent.aspectRatio(3/2, contentMode: .fit) // 2:3 vertical:horizontal for grid
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
