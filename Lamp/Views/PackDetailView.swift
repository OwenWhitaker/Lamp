import SwiftUI
import SwiftData

/// Collects each card's minY in the scroll coordinate space for live tilt.
private struct CardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] { [:] }
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, n in n }
    }
}

/// Reports the scroll view’s visible height so the bottom stack can be placed with only 6pt of the bottommost card visible.
private struct ScrollViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Returns true if any position changed by more than `tolerance` (or keys differ). Use a small tolerance so scroll-driven positions update smoothly without snapping.
private func cardMinYsChanged(_ newValue: [UUID: CGFloat], _ old: [UUID: CGFloat], tolerance: CGFloat = 0.1) -> Bool {
    guard newValue.count == old.count else { return true }
    for (id, newY) in newValue {
        guard let oldY = old[id] else { return true }
        if abs(newY - oldY) > tolerance { return true }
    }
    return false
}

struct PackDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var pack: Pack
    @Binding var path: NavigationPath
    @State private var searchText = ""
    @State private var showDeleteConfirmation = false
    @State private var showMemorization = false
    @State private var showAddVerse = false
    @State private var flipProgress: Double = 0

    private var filteredVerses: [Verse] {
        let list = pack.verses.sorted { $0.order < $1.order }
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return list }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return list.filter {
            $0.reference.lowercased().contains(q) || $0.text.lowercased().contains(q)
        }
    }

    private var averageMemoryHealth: Double {
        let withHealth = pack.verses.compactMap(\.memoryHealth)
        guard !withHealth.isEmpty else { return 0 }
        return withHealth.reduce(0, +) / Double(withHealth.count)
    }

    /// 3D tilt: top edge recedes into screen, bottom edge toward viewer (rotation around X axis).
    private let rolodexTilt: Double = -12

    /// Fixed height for all cards so they are uniform in the stack.
    private let rolodexCardHeight: CGFloat = 160

    /// Spacer between cards in the rolodex (angled cards use normal spacing; no condensed overlap).
    private let rolodexStackOverlap: CGFloat = 12

    /// Below this distance from prominence we start “speeding up” the approaching card so it spaces out (equal spacing until threshold).
    private let angledSpreadThreshold: CGFloat = 140
    /// Gap the approaching card opens so it doesn’t cover the prominent card until scrolled past.
    private let angledGapAtProminence: CGFloat = 44

    /// Fixed Y of the prominence slot.
    private let prominenceLine: CGFloat = 16
    /// Y below which cards start getting tilt (angled). Same distance as bottom-stack→angled for equivalent transition.
    private var angledStartY: CGFloat { prominenceLine + topStackToAngledTransitionHeight }
    /// Y where stack cards rest, stacked directly on top of one another (4, 10, 16, …).
    private let stackBaseY: CGFloat = 4
    /// Vertical offset per card in the stack (pixels).
    private let stackPixelOffset: CGFloat = 6
    /// Y where a card first appears when entering the stack (offset up from prominence line), then eases down to stackBaseY + idx*offset.
    private let stackEntryY: CGFloat = 12
    /// Distance over which a card eases from entry (at stackEntryY) into its final stack position (fluid motion).
    private let stackTransitionHeight: CGFloat = 100
    /// Max number of cards visible in the stack; the 4th and beyond are hidden behind the 3rd.
    private let maxVisibleStackCount: Int = 3

    /// Height of the visible sliver of the bottommost card above the pack footer (orange border).
    private let bottomStackVisibleSliver: CGFloat = 6
    /// Fallback when scroll height isn’t available yet; use a typical viewport height so the stack starts low.
    private let scrollViewHeightFallback: CGFloat = 580
    /// Y below which cards sit in the "bottom stack". Positioned so only the top `bottomStackVisibleSliver` of the bottommost card shows above the footer.
    private var bottomStackThresholdY: CGFloat {
        let justBelow = prominenceLine + rolodexCardHeight
        let base = justBelow + 1 * (rolodexCardHeight + rolodexStackOverlap)
        let h = scrollViewHeight > 0 ? scrollViewHeight : scrollViewHeightFallback
        let n = max(0, filteredVerses.count - prominentIndex - 2)
        guard n > 0 else { return base }
        return h - bottomStackVisibleSliver - CGFloat(n - 1) * bottomStackPixelOffset
    }
    /// Extra bottom padding so the bottom stack stays visible above the pack footer when scrolled.
    private let scrollBottomPaddingAboveFooter: CGFloat = 120
    /// Vertical offset per card in the bottom stack (same as top). Front card stays at fixed Y; positions are index-based so cards don’t shift as others leave.
    private let bottomStackPixelOffset: CGFloat = 6
    /// Distance over which a card tapers between flat and angled at top or bottom. Same value for equivalent feel.
    private let topStackToAngledTransitionHeight: CGFloat = 40
    /// Distance over which a card tapers from bottom-stack position into angled (scroll-driven).
    private let bottomStackToAngledTransitionHeight: CGFloat = 40

    /// ID of the verse at the scroll anchor (top); drives which card is prominent.
    @State private var scrollAnchorID: UUID?

    /// Each card's minY in the scroll coordinate space (live-updated as user scrolls).
    @State private var cardMinYs: [UUID: CGFloat] = [:]
    /// Scroll view’s visible height (from GeometryReader) so we can place the bottom stack with only 6pt of the bottommost card visible.
    @State private var scrollViewHeight: CGFloat = 0

    /// Index of the verse currently in prominence (at the top of the scroll).
    private var prominentIndex: Int {
        guard let id = scrollAnchorID else { return 0 }
        return filteredVerses.firstIndex(where: { $0.id == id }) ?? 0
    }

    /// Fixed spacing so layout never depends on geometry (avoids CPU spike from re-layout).
    private func spacingAfterCard(at index: Int) -> CGFloat {
        rolodexStackOverlap
    }

    /// No condensed overlap: angled cards use their natural layout position (spacing from rolodexStackOverlap).
    private func angledOverlapOffset(for verseID: UUID, index: Int, approachingVerseID: UUID?, transitioningVerseID: UUID?) -> CGFloat {
        0
    }

    /// The single verse that is “approaching prominence” (smallest minY >= justBelow). Used for visual speed-up/gap.
    private var approachingProminenceVerseID: UUID? {
        let justBelow = prominenceLine + rolodexCardHeight
        func effectiveMinY(_ v: Verse) -> CGFloat {
            if let y = cardMinYs[v.id] { return y }
            let i = filteredVerses.firstIndex(where: { $0.id == v.id }) ?? 0
            if i <= prominentIndex { return 0 }
            return prominenceLine + CGFloat(i - prominentIndex) * rolodexCardHeight
        }
        return filteredVerses
            .filter { effectiveMinY($0) >= justBelow }
            .min(by: { effectiveMinY($0) < effectiveMinY($1) })?
            .id
    }

    /// Verse in the prominence band with largest minY (card that just moved from angled into prominence). We taper its offset to 0 so no teleport.
    private var transitioningIntoProminenceVerseID: UUID? {
        let justBelow = prominenceLine + rolodexCardHeight
        return filteredVerses
            .filter { let y = cardMinYs[$0.id]; return y != nil && y! >= prominenceLine && y! <= justBelow }
            .max(by: { (cardMinYs[$0.id] ?? -1) < (cardMinYs[$1.id] ?? -1) })?
            .id
    }

    /// Card that should be shown as prominent: scroll anchor when set, else the card optically at the top (minY within threshold).
    /// Max distance below prominence line for a card to count as "optically in place" on the top stack.
    private let prominentAtTopThreshold: CGFloat = 44
    private var effectiveProminentVerseID: UUID? {
        if let id = scrollAnchorID { return id }
        let atTopMax = prominenceLine + prominentAtTopThreshold
        return filteredVerses
            .filter { let y = cardMinYs[$0.id]; return y != nil && y! >= prominenceLine && y! <= atTopMax }
            .min(by: { (cardMinYs[$0.id] ?? .infinity) < (cardMinYs[$1.id] ?? .infinity) })?
            .id
    }

    /// Visual-only offset: one continuous motion from angled into prominence. Anchor gets 0 so fast scrolls don’t leave it offset.
    private func angledVisualOffset(for verseID: UUID, approachingVerseID: UUID?, transitioningVerseID: UUID?) -> CGFloat {
        if verseID == effectiveProminentVerseID { return 0 }
        guard let minY = cardMinYs[verseID] else { return 0 }
        let justBelow = prominenceLine + rolodexCardHeight
        let bandHeight = justBelow - prominenceLine

        if minY > justBelow, verseID == approachingVerseID {
            let distBelow = min(minY - justBelow, angledSpreadThreshold)
            if distBelow <= 0 { return 0 }
            let t = distBelow / angledSpreadThreshold
            let tEased = t * t
            return angledGapAtProminence * (1 - tEased)
        }

        if minY >= prominenceLine, minY <= justBelow, verseID == transitioningVerseID {
            return angledGapAtProminence * (minY - prominenceLine) / bandHeight
        }

        return 0
    }

    /// 0 = far from prominence line, 1 = at prominent position. Anchor is always prominent so fast scrolls don’t leave it stuck angled.
    private func prominenceFactor(for verseID: UUID, index: Int) -> Double {
        if verseID == effectiveProminentVerseID { return 1 }
        if let minY = cardMinYs[verseID] {
            let distance = abs(minY - prominenceLine)
            let fadeDistance: CGFloat = 140
            return 1 - min(1, Double(distance / fadeDistance))
        }
        return index == prominentIndex ? 1 : 0
    }

    /// Smoothstep for zero derivative at 0 and 1 (no snap).
    private func smoothstep(_ t: Double) -> Double {
        let c = min(1, max(0, t))
        return c * c * (3 - 2 * c)
    }

    /// Tilt: 0 at prominent and bottom stack. Smooth ramp only from angled into prominent/top stack (prominenceLine … angledStartY).
    private func tiltDegrees(for verseID: UUID, index: Int) -> Double {
        if verseID == effectiveProminentVerseID { return 0 }
        guard let minY = cardMinYs[verseID] else {
            return index == prominentIndex ? 0 : rolodexTilt
        }
        if minY <= prominenceLine { return 0 }
        if minY > bottomStackThresholdY { return 0 }
        // Only smooth the angled → prominent/top stack transition
        if minY < angledStartY {
            let rampHeight = angledStartY - prominenceLine
            let t = Double((minY - prominenceLine) / rampHeight)
            return rolodexTilt * smoothstep(t)
        }
        let band = bottomStackThresholdY - angledStartY
        guard band > 0 else { return rolodexTilt }
        let t = Double((minY - angledStartY) / band)
        return rolodexTilt * (1 - min(1, max(0, t)))
    }

    /// All cards with minY < prominenceLine, sorted by minY ascending (index 0 = oldest = rank 0).
    private func sortedStackCards() -> [(id: UUID, minY: CGFloat)] {
        filteredVerses.compactMap { v -> (id: UUID, minY: CGFloat)? in
            guard let y = cardMinYs[v.id], y < prominenceLine else { return nil }
            return (v.id, y)
        }.sorted { $0.minY < $1.minY }
    }

    /// MinY of the card closest to the stack (smallest minY >= prominenceLine). Drives stack shift so it updates with scroll, not only after a card crosses.
    private func approachingCardMinY() -> CGFloat? {
        let above = filteredVerses.compactMap { cardMinYs[$0.id] }.filter { $0 >= prominenceLine }
        return above.min()
    }

    /// Progress 0...1 as the approaching card moves from (prominenceLine + distance) down to prominenceLine. Eased.
    private func stackShiftT(approachMinY: CGFloat?) -> CGFloat {
        let approach = approachMinY ?? (prominenceLine + stackTransitionHeight)
        let t = min(1, max(0, (prominenceLine + stackTransitionHeight - approach) / stackTransitionHeight))
        return 2 * t - t * t
    }

    /// For cards with minY < prominenceLine: index in the visible stack (0 = back, 2 = front). New card gets 2, previous 2→1, 1→0; the card that was at 0 gets nil and is drawn at stackBaseY behind the new index 0.
    private func stackIndex(for verseID: UUID) -> Int? {
        guard let myMinY = cardMinYs[verseID], myMinY < prominenceLine else { return nil }
        let sorted = sortedStackCards()
        let visibleStack = Array(sorted.suffix(maxVisibleStackCount))
        return visibleStack.firstIndex { $0.id == verseID }
    }

    /// Vertical offset for scrolled-past cards. Anchor never gets stack offset (it’s prominent).
    private func stackOffset(for verseID: UUID) -> CGFloat? {
        if verseID == effectiveProminentVerseID { return nil }
        guard let minY = cardMinYs[verseID], minY < prominenceLine else { return nil }
        let sorted = sortedStackCards()
        let n = sorted.count
        guard let rank = sorted.firstIndex(where: { $0.id == verseID }) else { return nil }

        let approachMinY = approachingCardMinY()
        let tShift = stackShiftT(approachMinY: approachMinY)

        if n <= 3 {
            if let idx = stackIndex(for: verseID) {
                let slotY: CGFloat
                if idx == 0 { slotY = stackBaseY }
                else if idx == 1 { slotY = stackBaseY + stackPixelOffset - 6 * tShift }
                else { slotY = stackBaseY + 2 * stackPixelOffset - 6 * tShift }
                let isFront = (idx == 2)
                if isFront {
                    return slotY - minY
                }
                let tSettle = min(1, (prominenceLine - minY) / stackTransitionHeight)
                let tSettleEased = 2 * tSettle - tSettle * tSettle
                let targetY = stackEntryY + (slotY - stackEntryY) * tSettleEased
                return targetY - minY
            }
            return stackBaseY - minY
        }

        let targetY: CGFloat
        if rank < n - 4 {
            targetY = stackBaseY
        } else if rank == n - 4 {
            targetY = stackBaseY
        } else if rank == n - 3 {
            targetY = stackBaseY
        } else if rank == n - 2 {
            targetY = stackBaseY + stackPixelOffset - 6 * tShift
        } else {
            targetY = stackBaseY + 2 * stackPixelOffset - 6 * tShift
        }
        return targetY - minY
    }

    /// Index-based rank in the bottom stack (0 = front card at fixed Y; cards keep their slot as others leave).
    private func bottomStackRank(for verseID: UUID, index: Int) -> Int? {
        let startIndex = prominentIndex + 2
        guard index >= startIndex else { return nil }
        return index - startIndex
    }

    /// Vertical offset for cards in the bottom stack. Front card stays at bottomStackThresholdY; positions are index-based so we don’t shift cards as others are pulled. Taper to 0 as minY approaches threshold for smooth transition into angled.
    private func bottomStackOffset(for verseID: UUID, index: Int) -> CGFloat? {
        if verseID == effectiveProminentVerseID { return nil }
        guard let minY = cardMinYs[verseID], minY > bottomStackThresholdY else { return nil }
        guard let rank = bottomStackRank(for: verseID, index: index) else { return nil }
        let stackTargetY = bottomStackThresholdY + CGFloat(rank) * bottomStackPixelOffset
        if minY >= bottomStackThresholdY + bottomStackToAngledTransitionHeight {
            return stackTargetY - minY
        }
        let t = (minY - bottomStackThresholdY) / bottomStackToAngledTransitionHeight
        let easeIn = 1 - (1 - t) * (1 - t)
        let targetY = bottomStackThresholdY + (stackTargetY - bottomStackThresholdY) * easeIn
        return targetY - minY
    }

    /// zIndex: effective prominent is always 1000. Else hidden top (300), visible top (400+), prominent (1000), angled (1100+), bottom stack (1200+).
    private func cardZIndex(verseID: UUID, index: Int) -> Double {
        if verseID == effectiveProminentVerseID { return 1000 }
        guard let minY = cardMinYs[verseID] else {
            return index == prominentIndex ? 1000 : 1100 + Double(index)
        }
        if minY > bottomStackThresholdY {
            if let rank = bottomStackRank(for: verseID, index: index) { return 1200 + Double(rank) }
            return 1200
        }
        if minY < prominenceLine {
            if let idx = stackIndex(for: verseID) { return 400 + Double(idx) }
            return 300
        }
        if minY >= prominenceLine, minY <= angledStartY { return 1000 }
        return 1100 + Double(index)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search this Pack:", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    if filteredVerses.isEmpty {
                        Button {
                            showAddVerse = true
                        } label: {
                            VStack(spacing: 8) {
                                Text("No verses")
                                    .font(.headline)
                                Text("Tap + to add verses")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        }
                        .buttonStyle(.plain)
                        .rolodexCardStyle()
                        .frame(height: rolodexCardHeight)
                    } else {
                        ForEach(Array(filteredVerses.enumerated()), id: \.element.id) { index, verse in
                            let factor = prominenceFactor(for: verse.id, index: index)
                            let tilt = tiltDegrees(for: verse.id, index: index)
                            let stackOff = stackOffset(for: verse.id) ?? 0
                            let angledOff = angledVisualOffset(for: verse.id, approachingVerseID: approachingProminenceVerseID, transitioningVerseID: transitioningIntoProminenceVerseID)
                            let isProminent = factor > 0.5
                            RolodexCardView(
                                verse: verse,
                                showFullVerse: true,
                                tiltDegrees: tilt,
                                isProminent: isProminent
                            ) {
                                path.append(verse)
                            }
                            .frame(height: rolodexCardHeight)
                            .offset(y: stackOff + angledOff + (bottomStackOffset(for: verse.id, index: index) ?? 0) + angledOverlapOffset(for: verse.id, index: index, approachingVerseID: approachingProminenceVerseID, transitioningVerseID: transitioningIntoProminenceVerseID))
                            .zIndex(cardZIndex(verseID: verse.id, index: index))
                            .id(verse.id)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: CardFramePreferenceKey.self, value: [verse.id: geo.frame(in: .named("scroll")).minY])
                                }
                            )

                            if index < filteredVerses.count - 1 {
                                Spacer()
                                    .frame(height: spacingAfterCard(at: index))
                            }
                        }
                    }
                }
                .padding(.top, prominenceLine)
                .padding(.horizontal, 20)
                .padding(.bottom, scrollBottomPaddingAboveFooter + CGFloat(max(16, filteredVerses.count * 48)))
                .onPreferenceChange(CardFramePreferenceKey.self) { newValue in
                    // Only update when positions changed meaningfully (tolerance avoids feedback loop and jitter).
                    if cardMinYsChanged(newValue, cardMinYs) {
                        cardMinYs = newValue
                    }
                }
            }
            .overlay(
                GeometryReader { geo in
                    Color.clear.preference(key: ScrollViewHeightKey.self, value: geo.size.height)
                }
                .allowsHitTesting(false)
            )
            .onPreferenceChange(ScrollViewHeightKey.self) { if $0 > 0 { scrollViewHeight = $0 } }
            .coordinateSpace(name: "scroll")
            .scrollPosition(id: $scrollAnchorID, anchor: .top)
            .onAppear {
                if scrollAnchorID == nil, let first = filteredVerses.first {
                    scrollAnchorID = first.id
                }
            }
            .onChange(of: filteredVerses.count) { _, _ in
                if scrollAnchorID == nil, let first = filteredVerses.first {
                    scrollAnchorID = first.id
                }
            }

            VStack(spacing: 12) {
                Text(pack.title)
                    .font(.title2.weight(.semibold))
                Text("\(pack.verses.count) verses | \(Int(averageMemoryHealth * 100))% avg memory health")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Review") {
                    showMemorization = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(pack.verses.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.orange, lineWidth: 2)
            )
        }
        .navigationTitle("My Packs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddVerse = true
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showAddVerse) {
            AddVerseView(pack: pack, isPresented: $showAddVerse)
        }
        .confirmationDialog("Delete Pack", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(pack)
                try? modelContext.save()
                path = NavigationPath()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(pack.title)\"? All verses will be removed.")
        }
        .fullScreenCover(isPresented: $showMemorization) {
            FlashcardView(pack: pack, verses: pack.verses.sorted { $0.order < $1.order })
        }
        .rotation3DEffect(.degrees(-90 + 90 * flipProgress), axis: (x: 0, y: 1, z: 0))
        .scaleEffect(0.95 + 0.05 * flipProgress)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                flipProgress = 1
            }
        }
    }
}

/// Single card used in the rolodex; tilt and full-verse visibility update live from scroll position.
struct RolodexCardView: View {
    let verse: Verse
    let showFullVerse: Bool
    let tiltDegrees: Double
    /// When true, this card is in the prominence slot and should look like it sits on top of the stack.
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(verse.reference)
                        .font(.headline)
                    Spacer()
                    if let health = verse.memoryHealth {
                        CircularProgressView(progress: health)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 32, height: 32)
                    }
                }
                if showFullVerse {
                    Text(verse.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
        }
        .buttonStyle(.plain)
        .rolodexCardStyle(prominent: isProminent)
        .rotation3DEffect(.degrees(tiltDegrees), axis: (x: 1, y: 0, z: 0))
    }
}

struct ProminentVerseCardView: View {
    let verse: Verse
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(verse.reference)
                        .font(.headline)
                    Spacer()
                    if let health = verse.memoryHealth {
                        CircularProgressView(progress: health)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 32, height: 32)
                    }
                }
                Text(verse.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
        }
        .buttonStyle(.plain)
        .rolodexCardStyle(prominent: true)
    }
}

struct VerseRowView: View {
    let verse: Verse
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(verse.reference)
                    .font(.headline)
                Spacer()
                if let health = verse.memoryHealth {
                    CircularProgressView(progress: health)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
        }
        .buttonStyle(.plain)
        .rolodexCardStyle(prominent: true)
    }
}

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

extension View {
    fileprivate func rolodexCardStyle(prominent: Bool = false) -> some View {
        let cornerRadius: CGFloat = prominent ? 12 : 10
        return self
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Color(.separator), lineWidth: 1)
                    )
            )
            .compositingGroup()
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    NavigationStack {
        PackDetailView(
            pack: Pack(title: "Preview Pack"),
            path: .constant(NavigationPath())
        )
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
