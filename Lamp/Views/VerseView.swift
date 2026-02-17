import SwiftUI
import SwiftData

private struct CardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Neumorphic Dot Indicator (Instagram-style sliding window)

private struct NeuDotIndicator: View {
    @Environment(\.colorScheme) private var colorScheme
    let count: Int
    let current: Int

    private let maxVisible = 5
    private let fullSize: CGFloat = 10
    private let smallSize: CGFloat = 5

    /// Window center lags behind `current` so you see the active dot move first
    @State private var windowCenter: Int = 0

    /// Window range based on the lagged center
    private var windowRange: Range<Int> {
        guard count > maxVisible else { return 0..<count }
        let half = maxVisible / 2
        let start = min(max(windowCenter - half, 0), count - maxVisible)
        return start..<(start + maxVisible)
    }

    /// Small dots at edges imply "more in that direction".
    /// At extremes, expand to 4 full-size dots on that side to show there's nothing further.
    private func dotSize(for index: Int) -> CGFloat {
        guard count > maxVisible else { return fullSize }
        let range = windowRange
        let pos = index - range.lowerBound // 0...4
        let atLeft = range.lowerBound == 0
        let atRight = range.upperBound == count

        if atLeft && atRight { return fullSize }
        if atLeft {
            // No more to the left — first 4 full, last 1 small
            return pos <= 3 ? fullSize : smallSize
        }
        if atRight {
            // No more to the right — last 4 full, first 1 small
            return pos >= 1 ? fullSize : smallSize
        }
        // Middle — outer 2 small, inner 3 full
        return (pos >= 1 && pos <= 3) ? fullSize : smallSize
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(windowRange), id: \.self) { index in
                let size = dotSize(for: index)
                ZStack {
                    if index == current {
                        ZStack {
                            NeuInset(shape: Circle())
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                        }
                        .frame(width: size, height: size)
                    } else {
                        // Bubble dot — raised with glossy highlight
                        ZStack {
                            Circle()
                                .fill(Color.neuBg)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 2, x: 1.5, y: 1.5)
                                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), radius: 2, x: -1, y: -1)

                            // Top-left specular highlight
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(colorScheme == .dark ? 0.12 : 0.6), Color.clear],
                                        center: .init(x: 0.35, y: 0.3),
                                        startRadius: 0,
                                        endRadius: size * 0.5
                                    )
                                )
                        }
                        .frame(width: size, height: size)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: windowCenter)
        .onAppear { windowCenter = current }
        .onChange(of: current) {
            // Delay the window scroll so the active dot moves first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    windowCenter = current
                }
            }
        }
    }
}

// MARK: - Verse View

struct VerseView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var verse: Verse
    @State private var isFlipped = false
    @State private var showDeleteConfirmation = false
    @State private var showEditVerse = false
    @State private var cardWidth: CGFloat = 0
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0

    private var sortedVerses: [Verse] {
        guard let pack = verse.pack else { return [verse] }
        return pack.verses.sorted { $0.order < $1.order }
    }

    private var currentVerse: Verse {
        let verses = sortedVerses
        guard currentIndex >= 0, currentIndex < verses.count else { return verse }
        return verses[currentIndex]
    }

    /// Card width relative to screen — leaves room for peek on each side
    private let peekAmount: CGFloat = 28
    private let cardSpacing: CGFloat = 12

    var body: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    cardCarousel
                    toolButtons
                }
                .padding(.top, 80)
                .padding(.bottom, 40)
            }

            // Floating header
            VStack(spacing: 0) {
                neuHeader
                    .background(Color.neuBg)

                LinearGradient(
                    colors: [Color.neuBg, Color.neuBg.opacity(0.85), Color.neuBg.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 24)
                .allowsHitTesting(false)

                Spacer()
            }
        }
        .navigationTitle(verse.reference)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            currentIndex = sortedVerses.firstIndex(of: verse) ?? 0
        }
        .sheet(isPresented: $showEditVerse) {
            EditVerseView(isPresented: $showEditVerse, verse: currentVerse)
        }
        .confirmationDialog("Delete Verse", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(currentVerse)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(currentVerse.reference)\"?")
        }
    }

    // MARK: - Neumorphic Header

    private var neuHeader: some View {
        HStack(spacing: 16) {
            NeuCircleButton(icon: "chevron.left") {
                dismiss()
            }

            Spacer()

            NeuCircleButton(icon: "ellipsis") {
                showEditVerse = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Card Carousel

    private var cardCarousel: some View {
        let verses = sortedVerses

        return VStack(spacing: 12) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let cardW = totalWidth - peekAmount * 2
                let step = cardW + cardSpacing

                HStack(spacing: cardSpacing) {
                    ForEach(Array(verses.enumerated()), id: \.element.id) { index, v in
                        singleCard(for: v, isCurrent: index == currentIndex)
                            .frame(width: cardW)
                    }
                }
                .offset(x: -CGFloat(currentIndex) * step + peekAmount + dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = step * 0.25
                            let predicted = value.predictedEndTranslation.width

                            var newIndex = currentIndex
                            if predicted < -threshold, currentIndex < verses.count - 1 {
                                newIndex = currentIndex + 1
                            } else if predicted > threshold, currentIndex > 0 {
                                newIndex = currentIndex - 1
                            }

                            withAnimation(.interpolatingSpring(stiffness: 260, damping: 24)) {
                                currentIndex = newIndex
                                dragOffset = 0
                            }
                        }
                )
                .animation(.interpolatingSpring(stiffness: 260, damping: 24), value: currentIndex)
            }
            .frame(height: cardMinHeight + 36) // card + padding

            Text("(Tap card to flip)")
                .font(.system(size: 14))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.25))

            if verses.count > 1 {
                NeuDotIndicator(count: verses.count, current: currentIndex)
            }
        }
    }

    private func singleCard(for v: Verse, isCurrent: Bool) -> some View {
        ZStack {
            if isFlipped {
                VStack(spacing: 16) {
                    Spacer()

                    // Verse text — left-aligned with first-line indent
                    (Text("     ") + Text(v.text))
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)

                    // Reference centered under the text
                    Text(v.reference)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))

                    Spacer()
                }
            } else {
                VStack {
                    Spacer()

                    Text(v.reference)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: CardWidthKey.self, value: geo.size.width)
            }
        )
        .frame(minHeight: cardMinHeight)
        .background(
            ZStack {
                NeuRaised(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Subtle top-left edge highlight for extra definition
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), Color.clear, Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .onPreferenceChange(CardWidthKey.self) { width in
            cardWidth = width
        }
        .onTapGesture {
            if isCurrent {
                withAnimation(.easeInOut(duration: 0.15)) { isFlipped.toggle() }
            }
        }
    }

    /// Minimum height for 3:2 aspect ratio based on card width
    private var cardMinHeight: CGFloat {
        cardWidth > 0 ? cardWidth / 1.5 : 200
    }

    // MARK: - Tool Buttons

    private var toolButtons: some View {
        VStack(spacing: 12) {
            toolButton("Flashcard") {
                withAnimation(.easeInOut(duration: 0.15)) { isFlipped.toggle() }
            }

            toolButton("Memorization Tool 2") {
                // Placeholder
            }

            toolButton("Memorization Tool 3") {
                // Placeholder
            }
        }
        .padding(.horizontal, 20)
    }

    private func toolButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                NeuRaised(
                    shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                    radius: 8,
                    distance: 6
                )
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let pack = Pack(title: "Romans 8")
    let v1 = Verse(reference: "Romans 8:1", text: "There is therefore now no condemnation for those who are in Christ Jesus.", order: 0)
    let v2 = Verse(reference: "Romans 8:28", text: "And we know that for those who love God all things work together for good.", order: 1)
    let v3 = Verse(reference: "Romans 8:38-39", text: "For I am sure that neither death nor life, nor angels nor rulers, nor things present nor things to come, nor powers, nor height nor depth, nor anything else in all creation, will be able to separate us from the love of God in Christ Jesus our Lord.", order: 2)
    v1.pack = pack
    v2.pack = pack
    v3.pack = pack
    pack.verses = [v1, v2, v3]

    return NavigationStack {
        VerseView(verse: v1)
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
