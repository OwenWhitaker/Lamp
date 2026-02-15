import SwiftUI
import SwiftData

// MARK: - Neumorphism Design System

private extension Color {
    static let neuBg = Color(red: 40 / 255, green: 40 / 255, blue: 50 / 255)
}

private extension LinearGradient {
    init(_ colors: Color...) {
        self.init(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct NeuRaised<S: Shape>: View {
    var shape: S
    var radius: CGFloat = 10
    var distance: CGFloat = 10

    var body: some View {
        shape
            .fill(Color.neuBg)
            .shadow(color: Color.black.opacity(0.4), radius: radius, x: distance, y: distance)
            .shadow(color: Color.white.opacity(0.08), radius: radius, x: -distance * 0.5, y: -distance * 0.5)
    }
}

private struct NeuInset<S: Shape>: View {
    var shape: S

    var body: some View {
        ZStack {
            shape.fill(Color.neuBg)
            shape
                .stroke(Color.black.opacity(0.5), lineWidth: 4)
                .blur(radius: 4)
                .offset(x: 2, y: 2)
                .mask(shape.fill(LinearGradient(Color.black, Color.clear)))
            shape
                .stroke(Color.white.opacity(0.12), lineWidth: 6)
                .blur(radius: 4)
                .offset(x: -2, y: -2)
                .mask(shape.fill(LinearGradient(Color.clear, Color.black)))
        }
    }
}

private struct NeuCircleButton: View {
    let icon: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                NeuRaised(shape: Circle(), radius: 6, distance: 5)
                    .frame(width: size, height: size)
                Image(systemName: icon)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Neumorphic Dot Indicator

private struct NeuDotIndicator: View {
    let count: Int
    let current: Int
    private let dotSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { index in
                ZStack {
                    if index == current {
                        ZStack {
                            NeuInset(shape: Circle())
                            Circle()
                                .fill(Color.white.opacity(0.06))
                        }
                        .frame(width: dotSize, height: dotSize)
                    } else {
                        // Bubble dot — raised with glossy highlight
                        ZStack {
                            Circle()
                                .fill(Color.neuBg)
                                .shadow(color: Color.black.opacity(0.4), radius: 2, x: 1.5, y: 1.5)
                                .shadow(color: Color.white.opacity(0.08), radius: 2, x: -1, y: -1)

                            // Top-left specular highlight
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(0.12), Color.clear],
                                        center: .init(x: 0.35, y: 0.3),
                                        startRadius: 0,
                                        endRadius: dotSize * 0.5
                                    )
                                )
                        }
                        .frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
    }
}

// MARK: - Verse View

struct VerseView: View {
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
                .foregroundStyle(Color.white.opacity(0.25))

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
                        .foregroundStyle(Color(white: 0.88))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)

                    // Reference centered under the text
                    Text(v.reference)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.35))

                    Spacer()
                }
            } else {
                VStack {
                    Spacer()

                    Text(v.reference)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(white: 0.88))

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
                            colors: [Color.white.opacity(0.08), Color.clear, Color.clear],
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
                    .foregroundStyle(Color.white.opacity(0.55))
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
