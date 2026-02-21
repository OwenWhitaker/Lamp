import SwiftUI
import SwiftData

private let packAccentPalette: [Color] = [
    Color(red: 0.94, green: 0.56, blue: 0.33), // orange
    Color(red: 0.37, green: 0.67, blue: 0.96), // blue
    Color(red: 0.38, green: 0.79, blue: 0.60), // mint
    Color(red: 0.82, green: 0.52, blue: 0.96), // violet
    Color(red: 0.62, green: 0.56, blue: 0.94)  // indigo
]

private func defaultAccentIndex(for id: UUID) -> Int {
    let seed = id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return seed % packAccentPalette.count
}

private func packAccentColor(for pack: Pack) -> Color {
    if pack.accentIndex == -1 {
        return .clear
    }
    let idx = pack.accentIndex ?? defaultAccentIndex(for: pack.id)
    return packAccentPalette[((idx % packAccentPalette.count) + packAccentPalette.count) % packAccentPalette.count]
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
    @State private var showColorSheet = false
    @State private var renameText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    private var useThirdsLayout: Bool { packs.count < 3 }

    var body: some View {
        Group {
            if useThirdsLayout {
                thirdsLayout
            } else {
                gridLayout
            }
        }
        .background(Color.neuBg.ignoresSafeArea())
        .sheet(isPresented: $showActionDialog, onDismiss: { packForAction = nil }) {
            packActionSheet
        }
        .sheet(isPresented: $showRenameSheet, onDismiss: { packForAction = nil }) {
            renameSheet
        }
        .sheet(isPresented: $showColorSheet, onDismiss: { packForAction = nil }) {
            colorSheet
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
        ZStack(alignment: .bottom) {
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
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 180)
            }

            if !packs.isEmpty {
                // Floating footer: gradient fade + circular add button
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.neuBg.opacity(0), Color.neuBg.opacity(0.85), Color.neuBg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 32)
                    .allowsHitTesting(false)

                    NeuCircleButton(icon: "plus", size: 48) {
                        showAddPack = true
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                    .frame(maxWidth: .infinity)
                    .background(Color.neuBg)
                }
            }
        }
        .background(Color.neuBg)
    }

    private var gridLayout: some View {
        ZStack(alignment: .bottom) {
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
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 180)
            }
            
            if !packs.isEmpty {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.neuBg.opacity(0), Color.neuBg.opacity(0.85), Color.neuBg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 32)
                    .allowsHitTesting(false)

                    NeuCircleButton(icon: "plus", size: 48) {
                        showAddPack = true
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                    .frame(maxWidth: .infinity)
                    .background(Color.neuBg)
                }
            }
        }
        .background(Color.neuBg)
    }

    // MARK: Rename Sheet

    private var renameSheet: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Rename Pack")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                    .padding(.top, 8)

                ZStack(alignment: .leading) {
                    NeuInset(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    TextField("Pack name", text: $renameText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.64))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .frame(height: 48)

                packMenuButton(title: "Save") {
                    if let pack = packForAction, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        pack.title = renameText.trimmingCharacters(in: .whitespaces)
                        try? modelContext.save()
                    }
                    showRenameSheet = false
                }
                .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(renameText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1)

                packMenuButton(title: "Cancel") {
                    showRenameSheet = false
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    private var packActionSheet: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            VStack(spacing: 14) {
                Text(packForAction?.title ?? "Pack")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 8)

                packMenuButton(title: "Rename") {
                    renameText = packForAction?.title ?? ""
                    showActionDialog = false
                    DispatchQueue.main.async { showRenameSheet = true }
                }

                packMenuButton(title: "Edit Color") {
                    showActionDialog = false
                    DispatchQueue.main.async { showColorSheet = true }
                }

                packMenuButton(
                    title: "Delete",
                    foreground: Color.red.opacity(colorScheme == .dark ? 0.82 : 0.72)
                ) {
                    if let pack = packForAction {
                        modelContext.delete(pack)
                        try? modelContext.save()
                    }
                    showActionDialog = false
                    packForAction = nil
                }

                packMenuButton(title: "Cancel") {
                    showActionDialog = false
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func packMenuButton(title: String, foreground: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                NeuRaised(shape: RoundedRectangle(cornerRadius: 16, style: .continuous), radius: 8, distance: 8)
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(foreground ?? (colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.62)))
            }
            .frame(height: 52)
        }
        .buttonStyle(.plain)
    }

    private var colorSheet: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Pack Color")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                    .padding(.top, 8)

                Text("Choose a color for this pack.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.5))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                    ForEach(0..<(packAccentPalette.count + 1), id: \.self) { slot in
                        let isBlank = slot == 0
                        let paletteIndex = slot - 1
                        let selectedIndex: Int? = packForAction.flatMap { pack -> Int? in
                            if pack.accentIndex == -1 { return nil }
                            return pack.accentIndex ?? defaultAccentIndex(for: pack.id)
                        }
                        let isSelected = isBlank ? (packForAction?.accentIndex == -1) : (selectedIndex == paletteIndex)

                        Button {
                            guard let pack = packForAction else { return }
                            pack.accentIndex = isBlank ? -1 : paletteIndex
                            try? modelContext.save()
                            showColorSheet = false
                        } label: {
                            ZStack {
                                NeuRaised(shape: Circle(), radius: 6, distance: 5)
                                    .frame(width: 58, height: 58)

                                if isBlank {
                                    Circle()
                                        .fill(Color.neuBg)
                                        .frame(width: 32, height: 32)
                                    Circle()
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.25), lineWidth: 1.5)
                                        .frame(width: 32, height: 32)
                                } else {
                                    Circle()
                                        .fill(packAccentPalette[paletteIndex].opacity(colorScheme == .dark ? 0.9 : 0.8))
                                        .frame(width: 32, height: 32)
                                }

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.75))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                packMenuButton(title: "Cancel") {
                    showColorSheet = false
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
    private var accent: Color { packAccentColor(for: pack) }

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
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .contentShape(.rect)
            .onTapGesture { action() }
            .onLongPressGesture(minimumDuration: 0.5) { onLongPress?() }
    }

    private var cardBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Each item (back + cards) gets one peek step above the pocket
            let peekPerItem = max(9, h * 0.1)
            let totalItems = 1 + cardCount     // 1 back panel + N verse cards
            let totalPeek = CGFloat(totalItems) * peekPerItem
            let pocketH = max(0, h - totalPeek)
            let pocketW = w
            let pocketTopY = totalPeek

            let cardW = max(0, pocketW - 12)
            let cardH = max(0, pocketH)

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

                // 3b. Subtle accent wash on pocket face.
                pocketShape
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(colorScheme == .dark ? 0.18 : 0.12),
                                accent.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
        VStack(spacing: 7) {
            Capsule()
                .fill(accent.opacity(colorScheme == .dark ? 0.85 : 0.75))
                .frame(width: min(42, max(22, pocketW * 0.22)), height: 6)

            Text(pack.title)
                .font(.system(h > 140 ? .title3 : .headline, design: .rounded).weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("\(verseCount) verse\(verseCount == 1 ? "" : "s")")
                .font(.system(h > 140 ? .subheadline : .caption, design: .rounded).weight(.medium))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
        }
        .frame(width: max(0, pocketW - 32))
        .position(x: w / 2, y: pocketTopY + pocketH * 0.5)
    }
}

// MARK: - Add Card

private struct NeuAddCard: View {
    @Environment(\.colorScheme) private var colorScheme
    var compact: Bool = false
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: neuCorner, style: .continuous)
    private let accent = Color(red: 0.37, green: 0.67, blue: 0.96)

    var body: some View {
        Button(action: action) {
            if compact {
                compactBody.frame(height: 70)
            } else {
                cardBody.aspectRatio(3.0 / 2.0, contentMode: .fit)
            }
        }
        .buttonStyle(.plain)
    }

    private var compactBody: some View {
        ZStack {
            NeuRaised(shape: shape)

            VStack(spacing: 4) {
                ZStack {
                    NeuRaised(shape: Circle(), radius: 4, distance: 4)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(accent.opacity(colorScheme == .dark ? 0.9 : 0.8))
                }
                Text("New Pack")
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(accent.opacity(colorScheme == .dark ? 0.7 : 0.65))
            }
        }
    }

    private var cardBody: some View {
        ZStack {
            NeuRaised(shape: shape)

            VStack(spacing: 12) {
                ZStack {
                    NeuRaised(shape: Circle(), radius: 5, distance: 5)
                        .frame(width: 48, height: 48)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(accent.opacity(colorScheme == .dark ? 0.92 : 0.82))
                }
                Text("New Pack")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(accent.opacity(colorScheme == .dark ? 0.72 : 0.66))
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
