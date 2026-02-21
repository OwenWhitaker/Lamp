import SwiftUI
import SwiftData

// MARK: - Memorization View

private let swipeThreshold: CGFloat = 140

struct MemorizationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let verses: [Verse]
    let pack: Pack?
    @State private var deck: [Verse] = []
    @State private var currentIndex: Int = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGFloat = 0
    @State private var showCongrats = false

    private var currentVerse: Verse? {
        guard deck.indices.contains(currentIndex) else { return nil }
        return deck[currentIndex]
    }

    /// Drag progress normalized to -1...1
    private var dragProgress: CGFloat {
        max(-1, min(1, dragOffset / swipeThreshold))
    }

    var body: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            if let verse = currentVerse {
                cardContent(verse: verse)
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
        .sheet(isPresented: $showCongrats, onDismiss: { dismiss() }) {
            CongratsView(verseCount: verses.count, packName: pack?.title)
        }
        .onAppear {
            isFlipped = false
            deck = verses.shuffled()
            if deck.isEmpty { dismiss() }
        }
        .onChange(of: currentIndex) { _, _ in
            isFlipped = false
            dragOffset = 0
        }
    }

    // MARK: - Header

    private var neuHeader: some View {
        HStack(spacing: 16) {
            NeuCircleButton(icon: "chevron.left") {
                dismiss()
            }

            Spacer()

            Text("\(currentIndex + 1) / \(deck.count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

            Spacer()

            // Invisible spacer to keep title centered
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Card Content

    private func cardContent(verse: Verse) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 84) // clear the header + gradient

            // Swipe labels above the card
            swipeHints

            // The swipeable card
            verseCard(verse: verse)
                .frame(maxHeight: 400)
                .padding(.horizontal, 20)
                .offset(x: dragOffset)
                .rotationEffect(.degrees(Double(dragProgress) * 8), anchor: .bottom)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let width = value.translation.width
                            if width < -swipeThreshold {
                                markNeedsWork()
                                animateCardOff(direction: -1)
                            } else if width > swipeThreshold {
                                markGotIt()
                                animateCardOff(direction: 1)
                            } else {
                                // Jiggle settle — bouncy spring overshoots past center
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.45, blendDuration: 0)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )

            Text("(Tap card to flip)")
                .font(.system(size: 13))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.25))
                .opacity(abs(dragOffset) > 0 ? 0 : 1)
                .animation(.easeInOut(duration: 0.15), value: dragOffset == 0)

            Spacer()
        }
    }

    // MARK: - Swipe Hints (Raised Tabs, Embossed Emissive Icons)

    private let xColor = Color(red: 1.0, green: 0.45, blue: 0.45)
    private let checkColor = Color(red: 0.45, green: 0.85, blue: 0.45)

    private func embossedIcon(_ name: String, color: Color, size: CGFloat = 24) -> some View {
        ZStack {
            // Emissive glow — blurred color halo behind the icon
            Image(systemName: name)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(color.opacity(0.5))
                .blur(radius: 4)

            // Shadow — dark above-left (top edge of the stamped groove is in shadow)
            Image(systemName: name)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black.opacity(colorScheme == .dark ? 0.7 : 0.4))
                .offset(x: -1.2, y: -1.2)
                .blur(radius: 0.8)

            // Lit edge — light below-right (bottom rim of groove catches the light)
            Image(systemName: name)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(colorScheme == .dark ? 0.25 : 0.95))
                .offset(x: 1, y: 1)

            // Base color
            Image(systemName: name)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
        }
    }

    /// Header buttons are centered at 20 (padding) + 22 (half of 44pt button) = 42pt from each edge.
    /// Tabs bleed off-screen, so the icon center should land at x=42 from the edge.
    /// With bleed=16, the visible portion starts at x=0-bleed. Icon is centered in the tab,
    /// so we position the tab so its center (accounting for bleed) aligns with x=42.
    private var swipeHints: some View {
        let tabH: CGFloat = 56
        let cornerR: CGFloat = tabH / 2
        let baseW: CGFloat = 60
        let bleed: CGFloat = 18
        let leftExtra: CGFloat = dragProgress < 0 ? abs(dragProgress) * 60 : 0
        let rightExtra: CGFloat = dragProgress > 0 ? dragProgress * 60 : 0

        return HStack {
            // Left: xmark — raised tab bleeding off left edge
            ZStack(alignment: .trailing) {
                NeuRaised(shape: UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 0,
                    bottomTrailingRadius: cornerR, topTrailingRadius: cornerR,
                    style: .continuous
                ), radius: 5, distance: 4)
                embossedIcon("xmark", color: xColor)
                    .frame(width: 44)
            }
            .frame(width: baseW + leftExtra, height: tabH)
            .offset(x: -bleed)
            .animation(.easeOut(duration: 0.15), value: dragProgress)

            Spacer()

            // Right: checkmark — raised tab bleeding off right edge
            ZStack(alignment: .leading) {
                NeuRaised(shape: UnevenRoundedRectangle(
                    topLeadingRadius: cornerR, bottomLeadingRadius: cornerR,
                    bottomTrailingRadius: 0, topTrailingRadius: 0,
                    style: .continuous
                ), radius: 5, distance: 4)
                embossedIcon("checkmark", color: checkColor)
                    .frame(width: 44)
            }
            .frame(width: baseW + rightExtra, height: tabH)
            .offset(x: bleed)
            .animation(.easeOut(duration: 0.15), value: dragProgress)
        }
        .padding(.horizontal, 0)
    }

    // MARK: - Verse Card (Tap to Flip)

    private func verseCard(verse: Verse) -> some View {
        ZStack {
            if isFlipped {
                // Back: verse text + reference below
                VStack(spacing: 16) {
                    Spacer()

                    Text("     \(verse.text)")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)

                    Text(verse.reference)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))

                    Spacer()
                }
            } else {
                // Front: reference centered
                VStack {
                    Spacer()

                    Text(verse.reference)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(
            ZStack {
                NeuRaised(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Subtle top-left edge highlight
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
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { isFlipped.toggle() }
        }
    }

    // MARK: - Actions

    private func animateCardOff(direction: Int) {
        let exitOffset = CGFloat(direction) * 500
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = exitOffset
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dragOffset = 0
            advance()
        }
    }

    private func markGotIt() {
        guard let verse = currentVerse else { return }
        verse.lastReviewed = Date()
        let current = verse.memoryHealth ?? 0
        verse.memoryHealth = min(1, current + 0.1)
        try? modelContext.save()
    }

    private func markNeedsWork() {
        guard let verse = currentVerse else { return }
        verse.lastReviewed = Date()
        let current = verse.memoryHealth ?? 0
        verse.memoryHealth = max(0, current - 0.1)
        try? modelContext.save()
        // Re-add to the end of the deck so it comes back around
        deck.append(verse)
    }

    private func advance() {
        if currentIndex < deck.count - 1 {
            currentIndex += 1
        } else {
            // All cards checked off — show congrats
            showCongrats = true
        }
    }
}

// MARK: - Congrats View

private struct CongratsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let verseCount: Int
    let packName: String?

    var body: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Emissive check icon
                ZStack {
                    // Glow
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(Color(red: 0.45, green: 0.85, blue: 0.45).opacity(0.4))
                        .blur(radius: 12)

                    NeuInset(shape: Circle())
                        .frame(width: 96, height: 96)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(Color(red: 0.45, green: 0.85, blue: 0.45))
                }

                Text("Stack Complete!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                VStack(spacing: 6) {
                    if let name = packName {
                        Text("You cleared every card in \(name).")
                            .font(.system(size: 16))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                    }
                    Text("\(verseCount) verse\(verseCount == 1 ? "" : "s") memorized")
                        .font(.system(size: 14))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                }

                Button {
                    dismiss()
                } label: {
                    ZStack {
                        NeuRaised(shape: RoundedRectangle(cornerRadius: 16, style: .continuous), radius: 8, distance: 6)
                            .frame(height: 50)
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 160)
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }
}

// MARK: - Session Settings Placeholder

struct SessionSettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Session order and options coming soon.")
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Session Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    MemorizationView(
        verses: [
            Verse(reference: "John 3:16", text: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.", order: 0),
            Verse(reference: "Romans 8:28", text: "And we know that for those who love God all things work together for good.", order: 1)
        ],
        pack: nil
    )
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
