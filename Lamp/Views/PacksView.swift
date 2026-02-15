import SwiftUI
import SwiftData

// MARK: - Neumorphism Design System
// Based on https://hackingwithswift.com/articles/213/how-to-build-neumorphic-designs-with-swiftui
// Elements are the SAME color as the background. Depth comes only from shadows.
// Light source: top-left. Dark shadow cast further than light highlight (asymmetric).

private extension Color {
    static let neuBg = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 40/255, green: 40/255, blue: 50/255, alpha: 1)
            : UIColor(red: 225/255, green: 225/255, blue: 235/255, alpha: 1)
    })
}

private extension LinearGradient {
    init(_ colors: Color...) {
        self.init(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private let neuCorner: CGFloat = 22

// MARK: - Neumorphic Primitives

/// Raised surface -- extruded from the background with flat fill.
private struct NeuRaised<S: Shape>: View {
    @Environment(\.colorScheme) private var colorScheme
    var shape: S
    var radius: CGFloat = 10
    var distance: CGFloat = 10

    var body: some View {
        shape
            .fill(Color.neuBg)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.3), radius: radius, x: distance, y: distance)
            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 1.0), radius: radius, x: -distance * 0.5, y: -distance * 0.5)
    }
}

/// Inset surface -- pressed into the background (blur + gradient-mask inner shadow).
private struct NeuInset<S: Shape>: View {
    @Environment(\.colorScheme) private var colorScheme
    var shape: S

    var body: some View {
        ZStack {
            shape.fill(Color.neuBg)
            shape
                .stroke(Color(white: colorScheme == .dark ? 0 : 0.5).opacity(colorScheme == .dark ? 0.5 : 0.5), lineWidth: 4)
                .blur(radius: 4)
                .offset(x: 2, y: 2)
                .mask(shape.fill(LinearGradient(Color.black, Color.clear)))
            shape
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 1.0), lineWidth: 6)
                .blur(radius: 4)
                .offset(x: -2, y: -2)
                .mask(shape.fill(LinearGradient(Color.clear, Color.black)))
        }
    }
}

// MARK: - PacksView

struct PacksView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pack.createdAt, order: .reverse) private var packs: [Pack]
    @Binding var path: NavigationPath
    @Binding var showAddPack: Bool

    @State private var packForAction: Pack?
    @State private var showActionDialog = false
    @State private var showRenameSheet = false
    @State private var renameText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    private var useThirdsLayout: Bool { packs.count <= 2 }

    var body: some View {
        Group {
            if useThirdsLayout {
                thirdsLayout
            } else {
                gridLayout
            }
        }
        .background(Color.neuBg.ignoresSafeArea())
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
            Button("Cancel", role: .cancel) { packForAction = nil }
        } message: {
            Text(packForAction.map { "\"\($0.title)\"" } ?? "")
        }
        .sheet(isPresented: $showRenameSheet, onDismiss: { packForAction = nil }) {
            renameSheet
        }
    }

    // MARK: Title Header

    private var titleHeader: some View {
        Text("My Packs")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 4)
    }

    // MARK: Layouts

    private var thirdsLayout: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                titleHeader

                if packs.isEmpty {
                    NeuAddCard { showAddPack = true }
                } else {
                    ForEach(packs) { pack in
                        NeuPackCard(pack: pack, action: { path.append(pack) }, onLongPress: {
                            packForAction = pack
                            showActionDialog = true
                        })
                    }
                    NeuAddCard { showAddPack = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 80) // clear the floating tab bar
        }
        .background(Color.neuBg)
    }

    private var gridLayout: some View {
        ScrollView {
            VStack(spacing: 20) {
                titleHeader

                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(packs) { pack in
                        NeuPackCard(pack: pack, action: { path.append(pack) }, onLongPress: {
                            packForAction = pack
                            showActionDialog = true
                        })
                    }
                    NeuAddCard { showAddPack = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 80)
        }
        .background(Color.neuBg)
    }

    // MARK: Rename Sheet

    private var renameSheet: some View {
        NavigationStack {
            Form {
                TextField("Pack name", text: $renameText)
            }
            .navigationTitle("Rename Pack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRenameSheet = false }
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

// MARK: - Pack Card (Pocket Holding Cards)
//
// Modelled after a physical verse card pocket:
//   - Full-size card rectangles z-stacked behind a front pocket panel
//   - Each card is offset slightly upward so its top edge peeks above the one in front
//   - The pocket covers the bottom ~60%, hiding most of each card
//   - Sharp top edge on the pocket (the slot opening), rounded bottom

private struct NeuPackCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let pack: Pack
    let action: () -> Void
    var onLongPress: (() -> Void)? = nil

    // Pocket: sharp top (card slot opening), rounded bottom
    private let pocketShape = UnevenRoundedRectangle(
        topLeadingRadius: 3, bottomLeadingRadius: neuCorner,
        bottomTrailingRadius: neuCorner, topTrailingRadius: 3,
        style: .continuous
    )
    private let cardShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    private var verseCount: Int { pack.verses.count }
    // Show up to 3 full card shapes behind the pocket
    private var cardCount: Int { min(verseCount, 3) }

    var body: some View {
        cardBody
            .aspectRatio(2.0 / 1.0, contentMode: .fit)
            .contentShape(.rect)
            .onTapGesture { action() }
            .onLongPressGesture(minimumDuration: 0.5) { onLongPress?() }
    }

    private var cardBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Each item (back + cards) gets one peek step above the pocket
            let peekPerItem = max(6, h * 0.07)
            let totalItems = 1 + cardCount     // 1 back panel + N verse cards
            let totalPeek = CGFloat(totalItems) * peekPerItem
            let pocketH = h - totalPeek
            let pocketW = w
            let pocketTopY = totalPeek

            let cardW = pocketW - 12
            let cardH = pocketH

            ZStack {
                // 1. Back panel (always present -- the holder back, lowest z)
                NeuRaised(shape: cardShape, radius: 8, distance: 8)
                    .frame(width: cardW, height: cardH)
                    .position(x: w / 2, y: cardH / 2)

                // 2. Verse cards z-stacked in front of the back
                if cardCount > 0 {
                    cardsLayer(
                        w: w, pocketTopY: pocketTopY,
                        cardW: cardW, cardH: cardH,
                        peekPerItem: peekPerItem
                    )
                }

                // 3. Pocket front panel (highest z -- covers card bodies)
                NeuRaised(shape: pocketShape)
                    .frame(width: pocketW, height: pocketH)
                    .position(x: w / 2, y: pocketTopY + pocketH / 2)

                // 4. Title + verse count on the pocket face
                titleLayer(w: w, pocketTopY: pocketTopY, pocketH: pocketH, pocketW: pocketW, h: h)
            }
        }
    }

    // MARK: Cards

    @ViewBuilder
    private func cardsLayer(
        w: CGFloat, pocketTopY: CGFloat,
        cardW: CGFloat, cardH: CGFloat,
        peekPerItem: CGFloat
    ) -> some View {
        ForEach(0..<cardCount, id: \.self) { i in
            // Back card (i=0) peeks the most, front card peeks the least.
            // Offset by 1 because slot 0 is the back panel.
            let cardTopY = CGFloat(1 + i) * peekPerItem

            NeuRaised(shape: cardShape, radius: 8, distance: 8)
                .frame(width: cardW, height: cardH)
                .position(x: w / 2, y: cardTopY + cardH / 2)
        }
    }

    // MARK: Title

    @ViewBuilder
    private func titleLayer(w: CGFloat, pocketTopY: CGFloat, pocketH: CGFloat, pocketW: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(pack.title)
                .font(.system(h > 140 ? .title3 : .headline, design: .rounded).weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("\(verseCount) verse\(verseCount == 1 ? "" : "s")")
                .font(.system(h > 140 ? .subheadline : .caption, design: .rounded).weight(.medium))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
        }
        .frame(width: pocketW - 32)
        .position(x: w / 2, y: pocketTopY + pocketH * 0.5)
    }
}

// MARK: - Add Card

private struct NeuAddCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: neuCorner, style: .continuous)

    var body: some View {
        Button(action: action) {
            cardBody
                .aspectRatio(2.0 / 1.0, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    private var cardBody: some View {
        ZStack {
            // Simple raised card (no pocket -- it's a CTA, not a pack)
            NeuRaised(shape: shape)

            VStack(spacing: 12) {
                // Raised circular plus button
                ZStack {
                    NeuRaised(shape: Circle(), radius: 5, distance: 5)
                        .frame(width: 48, height: 48)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                }

                Text("New Pack")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PacksView(path: .constant(NavigationPath()), showAddPack: .constant(false))
            .navigationTitle("My Packs")
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
