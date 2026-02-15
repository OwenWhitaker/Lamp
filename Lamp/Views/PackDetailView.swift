import SwiftUI
import SwiftData

// MARK: - Neumorphism Design System

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

private struct SwipeableVerseRow: View {
    let verse: Verse
    @Binding var openSwipeVerseId: UUID?
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @GestureState private var dragX: CGFloat = 0
    @State private var isHorizontalDrag: Bool?

    private let actionSize: CGFloat = 48
    private let actionGap: CGFloat = 10
    private var maxReveal: CGFloat { actionSize * 2 + actionGap + 24 }
    private var effectiveOffset: CGFloat { rubberBand(offsetX + dragX) }
    private var settleSpring: Animation {
        .interpolatingSpring(stiffness: 260, damping: 22)
    }

    @State private var didSwipe = false

    var body: some View {
        ZStack {
            actionRow
            NeuVerseCard(verse: verse)
                .offset(x: effectiveOffset)
                .onTapGesture {
                    guard !didSwipe else {
                        didSwipe = false
                        return
                    }
                    if offsetX != 0 {
                        // Close open swipe instead of navigating
                        withAnimation(settleSpring) { offsetX = 0 }
                        openSwipeVerseId = nil
                    } else {
                        onTap()
                    }
                }
                .simultaneousGesture(dragGesture)
        }
        .onChange(of: openSwipeVerseId) {
            if openSwipeVerseId != verse.id, offsetX != 0 {
                withAnimation(settleSpring) {
                    offsetX = 0
                }
            }
        }
    }

    private var actionRow: some View {
        HStack {
            HStack(spacing: actionGap) {
                Button(action: onDelete) {
                    NeuSwipeActionCircle(icon: "trash", size: actionSize, iconColor: .red)
                }
                .buttonStyle(.plain)

                Button(action: onEdit) {
                    NeuSwipeActionCircle(icon: "square.and.pencil", size: actionSize)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
    }

    /// Horizontal dead zone before swipe engages — gives ScrollView priority
    private let swipeDeadZone: CGFloat = 5

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .updating($dragX) { value, state, _ in
                guard isHorizontalDrag == true else { return }
                // Subtract dead zone so the card doesn't jump
                let adjusted = value.translation.width - (value.translation.width > 0 ? swipeDeadZone : -swipeDeadZone)
                state = adjusted
            }
            .onChanged { value in
                // Lock direction once past the dead zone
                if isHorizontalDrag == nil,
                   abs(value.translation.width) > swipeDeadZone {
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height) * 1.8
                }
                guard isHorizontalDrag == true else { return }
                if openSwipeVerseId != verse.id {
                    openSwipeVerseId = verse.id
                }
            }
            .onEnded { value in
                defer { isHorizontalDrag = nil }
                guard isHorizontalDrag == true else { return }
                didSwipe = true
                let raw = offsetX + value.translation.width
                let current = clamped(raw)

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    offsetX = raw
                }

                let shouldOpen = current > maxReveal * 0.35

                if shouldOpen {
                    withAnimation(settleSpring) {
                        offsetX = maxReveal
                    }
                    openSwipeVerseId = verse.id
                } else {
                    withAnimation(settleSpring) {
                        offsetX = 0
                    }
                    if openSwipeVerseId == verse.id {
                        openSwipeVerseId = nil
                    }
                }
            }
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), maxReveal)
    }

    private func rubberBand(_ value: CGFloat) -> CGFloat {
        if value < 0 {
            let d = abs(value)
            return -18 * log1p(d / 18)
        }
        if value > maxReveal {
            let over = value - maxReveal
            return maxReveal + 18 * log1p(over / 18)
        }
        return value
    }
}

struct EditVerseView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @Bindable var verse: Verse

    var body: some View {
        NavigationStack {
            Form {
                TextField("Reference", text: $verse.reference, prompt: Text("e.g. John 3:16"))
                TextField("Verse text", text: $verse.text, axis: .vertical)
                    .lineLimit(5...20)
            }
            .navigationTitle("Edit Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? modelContext.save()
                        isPresented = false
                    }
                    .disabled(verse.reference.trimmingCharacters(in: .whitespaces).isEmpty || verse.text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Raised surface -- extruded from the background with flat fill.
private struct NeuRaised<S: Shape>: View {
    @Environment(\.colorScheme) private var colorScheme
    var shape: S
    var radius: CGFloat = 10
    var distance: CGFloat = 10

    var body: some View {
        shape
            .fill(Color.neuBg)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: radius, x: distance, y: distance)
            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), radius: radius, x: -distance * 0.5, y: -distance * 0.5)
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

// MARK: - Shared Layout

/// Shared card dimensions for verse cards. Used by PackDetailView and FlashcardView.
enum VerseCardLayout {
    static let cardHeight: CGFloat = 160
    static let horizontalPadding: CGFloat = 12
}

// MARK: - Pack Detail View

struct PackDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var pack: Pack
    @Binding var path: NavigationPath

    @State private var showDeleteConfirmation = false
    @State private var showMemorization = false
    @State private var showAddVerse = false
    @State private var showEditVerse = false
    @State private var pendingVerseDelete: Verse?
    @State private var pendingVerseEdit: Verse?
    @State private var openSwipeVerseId: UUID?

    private var sortedVerses: [Verse] {
        pack.verses.sorted { $0.order < $1.order }
    }

    private var averageMemoryHealth: Double {
        let withHealth = pack.verses.compactMap(\.memoryHealth)
        guard !withHealth.isEmpty else { return 0 }
        return withHealth.reduce(0, +) / Double(withHealth.count)
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen neuBg
            Color.neuBg.ignoresSafeArea()

            // Main content: scroll view fills screen, header floats on top
            verseList

            // Floating header with gradient fade
            VStack(spacing: 0) {
                neuHeader
                    .background(Color.neuBg)

                // Soft gradient fade so cards blend under the header
                LinearGradient(
                    colors: [Color.neuBg, Color.neuBg.opacity(0.85), Color.neuBg.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 24)
                .allowsHitTesting(false)

                Spacer()
            }

            // Floating footer
            neuFooter
        }
        .navigationTitle("My Packs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddVerse) {
            AddVerseView(pack: pack, isPresented: $showAddVerse)
        }
        .sheet(isPresented: $showEditVerse) {
            if let verse = pendingVerseEdit {
                EditVerseView(isPresented: $showEditVerse, verse: verse)
            }
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
        .confirmationDialog("Delete Verse", isPresented: Binding(
            get: { pendingVerseDelete != nil },
            set: { if !$0 { pendingVerseDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                deletePendingVerse()
            }
            Button("Cancel", role: .cancel) {
                pendingVerseDelete = nil
            }
        } message: {
            let ref = pendingVerseDelete?.reference ?? "this verse"
            Text("Are you sure you want to delete \"\(ref)\"?")
        }
    }

    // MARK: - Neumorphic Header

    private var neuHeader: some View {
        HStack(spacing: 16) {
            // Back button
            NeuCircleButton(icon: "chevron.left") {
                dismiss()
            }

            Spacer()

            // Pack title
            Text(pack.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            // Add verse button
            NeuCircleButton(icon: "plus") {
                showAddVerse = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Verse List

    private var verseList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if sortedVerses.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(sortedVerses) { verse in
                        SwipeableVerseRow(
                            verse: verse,
                            openSwipeVerseId: $openSwipeVerseId,
                            onTap: { path.append(verse) },
                            onEdit: {
                                pendingVerseEdit = verse
                                showEditVerse = true
                            },
                            onDelete: {
                                pendingVerseDelete = verse
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 80)
                .padding(.bottom, 200)
            }
        }
    }

    private func deletePendingVerse() {
        guard let verse = pendingVerseDelete else { return }
        modelContext.delete(verse)
        try? modelContext.save()
        pendingVerseDelete = nil
    }

    // MARK: Empty / No Results

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 120) // clear the floating header

            // Neumorphic inset circle icon
            ZStack {
                NeuInset(shape: Circle())
                    .frame(width: 80, height: 80)
                Image(systemName: "book.closed")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.25))
            }

            Text("No verses yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))

            Text("Tap + to add your first verse")
                .font(.system(size: 15))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3))

            // Add verse raised button
            Button {
                showAddVerse = true
            } label: {
                ZStack {
                    NeuRaised(shape: RoundedRectangle(cornerRadius: 16, style: .continuous), radius: 8, distance: 6)
                        .frame(height: 50)
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Add Verse")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            .frame(width: 180)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 140)
    }

    // MARK: - Floating Neumorphic Footer

    private var neuFooter: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [Color.neuBg.opacity(0), Color.neuBg.opacity(0.85), Color.neuBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            // Footer content
            HStack(spacing: 16) {
                // Stats
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(pack.verses.count) verse\(pack.verses.count == 1 ? "" : "s")")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                    if !pack.verses.isEmpty {
                        HStack(spacing: 6) {
                            NeuProgressRing(progress: averageMemoryHealth, size: 18)
                            Text("\(Int(averageMemoryHealth * 100))% memorized")
                                .font(.system(size: 12))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                        }
                    }
                }

                Spacer()

                // Review button
                Button {
                    showMemorization = true
                } label: {
                    ZStack {
                        NeuRaised(
                            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                            radius: 8,
                            distance: 6
                        )
                        Text("Review")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .disabled(pack.verses.isEmpty)
                .opacity(pack.verses.isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 120) // clear the tab bar
            .background(Color.neuBg)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Neumorphic Circle Button

private struct NeuCircleButton: View {
    @Environment(\.colorScheme) private var colorScheme
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
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct NeuSwipeActionCircle: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    var size: CGFloat = 44
    var iconColor: Color? = nil

    var body: some View {
        ZStack {
            NeuRaised(shape: Circle(), radius: 6, distance: 5)
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(iconColor ?? (colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.45)))
        }
        .contentShape(Circle())
    }
}

// MARK: - Neumorphic Verse Card

private struct NeuVerseCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let verse: Verse

    var body: some View {
        HStack(spacing: 14) {
            // Left: reference + text preview
            VStack(alignment: .leading, spacing: 6) {
                Text(verse.reference)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                Text(verse.text)
                    .font(.system(size: 14))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: memory health ring
            if let health = verse.memoryHealth {
                NeuProgressRing(progress: health, size: 36)
            } else {
                // Empty neumorphic inset circle
                NeuInset(shape: Circle())
                    .frame(width: 36, height: 36)
            }
        }
        .padding(18)
        .background(
            NeuRaised(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .padding(.vertical, 8)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Neumorphic Progress Ring

private struct NeuProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double
    var size: CGFloat = 36

    private var ringColor: Color {
        if progress >= 0.75 {
            return Color(red: 0.55, green: 0.78, blue: 0.95) // light blue
        }
        // Lerp from red (0%) to yellow (75%)
        let t = max(0, progress / 0.75)
        let r = 0.9 + (0.95 - 0.9) * t   // 0.9 → 0.95
        let g = 0.3 + (0.8 - 0.3) * t     // 0.3 → 0.8
        let b = 0.25 + (0.3 - 0.25) * t   // 0.25 → 0.3
        return Color(red: r, green: g, blue: b)
    }

    private var grooveWidth: CGFloat { size > 24 ? 4 : 3 }
    // The groove sits centered on this radius
    private var grooveRadius: CGFloat { (size - grooveWidth) / 2 }

    var body: some View {
        ZStack {
            // 1. Raised disc — the whole circle is extruded from the card
            Circle()
                .fill(Color.neuBg)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 3, x: 2, y: 2)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), radius: 3, x: -1, y: -1)

            // 2. Groove channel — ring-shaped inset cut into the disc
            // Outer border of the groove
            Circle()
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5)
                .frame(width: size - 1, height: size - 1)

            // Groove floor — slightly darker than the disc surface
            Circle()
                .stroke(Color.black.opacity(0.04), lineWidth: grooveWidth)

            // Groove inset shadow — dark on top-left, light on bottom-right
            Circle()
                .stroke(Color.black.opacity(0.12), lineWidth: grooveWidth)
                .blur(radius: 0.5)
                .offset(x: -0.5, y: -0.5)
                .mask(Circle().stroke(lineWidth: grooveWidth + 1))

            Circle()
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.7), lineWidth: grooveWidth)
                .blur(radius: 0.5)
                .offset(x: 0.5, y: 0.5)
                .mask(Circle().stroke(lineWidth: grooveWidth + 1))

            // 3. Emissive glow behind the progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor.opacity(0.4),
                    style: StrokeStyle(lineWidth: grooveWidth + 2, lineCap: .round)
                )
                .blur(radius: 2)
                .rotationEffect(.degrees(-90))

            // 4. Progress arc — slightly raised from the groove floor
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: grooveWidth - 0.5, lineCap: .round)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 0.5, x: 0.5, y: 0.5)
                .shadow(color: Color.white.opacity(0.4), radius: 0.5, x: -0.3, y: -0.3)
                .rotationEffect(.degrees(-90))

            // 5. Percentage label
            if size >= 36 {
                Text("\(Int(progress * 100))")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Legacy Types (used by FlashcardView)

struct CircularProgressView: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PackDetailView(
            pack: Pack(title: "Romans 8"),
            path: .constant(NavigationPath())
        )
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
