import SwiftUI
import SwiftData

// MARK: - Tappable Card (tap to flip)

private struct TappableCard: View {
    let verse: Verse
    @Binding var isFlipped: Bool
    var showBackReference: Bool = true

    var body: some View {
        NeuFlippableCard(verse: verse, isFlipped: isFlipped, showBackReference: showBackReference)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) { isFlipped.toggle() }
            }
    }
}

// MARK: - Flippable Card (3:2 aspect, tap to flip)

private struct NeuFlippableCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let verse: Verse
    var isFlipped: Bool
    var showBackReference: Bool = true

    var body: some View {
        ZStack {
            if isFlipped {
                // Back face: verse text centered + optional reference at bottom
                VStack(spacing: 0) {
                    Spacer()

                    Text("     \(verse.text)")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    if showBackReference {
                        Text(verse.reference)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                    }
                }
            } else {
                // Front face: reference centered
                Text(verse.reference)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
        .aspectRatio(3.0 / 2.0, contentMode: .fit)
        .background(
            ZStack {
                NeuRaised(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))

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
    }
}

// MARK: - Edit Verse View

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

// MARK: - Shared Layout

/// Shared card dimensions for verse cards. Used by FlashcardView.
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
    let initialVerseID: UUID?

    @State private var showDeleteConfirmation = false
    @State private var showMemorization = false
    @State private var showAddVerse = false
    @State private var showEditVerse = false
    @State private var pendingVerseDelete: Verse?
    @State private var pendingVerseEdit: Verse?
    @State private var currentIndex: Int = 0
    @State private var dragOffsetX: CGFloat = 0
    @State private var isFlipped: Bool = false
    @State private var showOptions: Bool = false
    @State private var showBackReference: Bool = true
    @State private var didApplyInitialVerseFocus = false

    private var sortedVerses: [Verse] {
        pack.verses.sorted { $0.order < $1.order }
    }

    private var averageMemoryHealth: Double {
        let withHealth = pack.verses.compactMap(\.memoryHealth)
        guard !withHealth.isEmpty else { return 0 }
        return withHealth.reduce(0, +) / Double(withHealth.count)
    }

    /// Horizontal peek — how much of adjacent cards is visible at the edges
    private let peekAmount: CGFloat = 24
    private let cardSpacing: CGFloat = 14

    private let pageAnimation: Animation = .easeOut(duration: 0.15)

    init(pack: Pack, path: Binding<NavigationPath>, initialVerseID: UUID? = nil) {
        self.pack = pack
        self._path = path
        self.initialVerseID = initialVerseID
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.neuBg.ignoresSafeArea()

            // Card area fills the space between header and footer
            verseContent

            // Floating header with gradient fade
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

            neuFooter
        }
        .navigationTitle("My Packs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showOptions) {
            PackOptionsSheet(
                isPresented: $showOptions,
                showBackReference: $showBackReference,
                onEditPack: { },
                onDeletePack: { showDeleteConfirmation = true }
            )
        }
        .sheet(isPresented: $showAddVerse) {
            NeuAddVerseSheet(pack: pack, isPresented: $showAddVerse)
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
        .navigationDestination(isPresented: $showMemorization) {
            MemorizationView(verses: pack.verses.sorted { $0.order < $1.order }, pack: pack)
                .toolbar(.hidden, for: .navigationBar)
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
        .onAppear {
            markPackAccess()
            applyInitialVerseFocusIfNeeded()
        }
    }

    // MARK: - Neumorphic Header

    private var neuHeader: some View {
        HStack(spacing: 16) {
            NeuCircleButton(icon: "chevron.left") {
                dismiss()
            }

            Spacer()

            Text(pack.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            NeuCircleButton(icon: "ellipsis") {
                showOptions = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Verse Content (horizontal paging carousel)

    private var verseContent: some View {
        Group {
            if sortedVerses.isEmpty {
                emptyState
            } else {
                let verses = sortedVerses
                GeometryReader { geo in
                    let totalHeight = geo.size.height
                    let headerInset: CGFloat = 80
                    let footerInset: CGFloat = 160
                    let availableHeight = totalHeight - headerInset - footerInset

                    // Card width = most of screen, leaving peek room at edges
                    let cardW = geo.size.width - peekAmount * 2 - cardSpacing * 2
                    // Height from 3:2 aspect, capped to available space
                    let cardH = min(cardW / 1.5, availableHeight)
                    let step = cardW + cardSpacing

                    HStack(spacing: cardSpacing) {
                        ForEach(Array(verses.enumerated()), id: \.element.id) { index, verse in
                            TappableCard(verse: verse, isFlipped: $isFlipped, showBackReference: showBackReference)
                                .frame(width: cardW, height: cardH)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .offset(x: geo.size.width / 2 - cardW / 2 - CGFloat(currentIndex) * step + dragOffsetX)
                    .padding(.top, headerInset)
                    .padding(.bottom, footerInset)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                dragOffsetX = value.translation.width
                            }
                            .onEnded { value in
                                let predicted = value.predictedEndTranslation.width
                                let threshold: CGFloat = step * 0.15
                                var newIndex = currentIndex

                                if predicted < -threshold {
                                    newIndex = min(currentIndex + 1, verses.count - 1)
                                } else if predicted > threshold {
                                    newIndex = max(currentIndex - 1, 0)
                                }

                                withAnimation(pageAnimation) {
                                    currentIndex = newIndex
                                    dragOffsetX = 0
                                }
                            }
                    )
                }
                .clipped()
            }
        }
    }

    private func deletePendingVerse() {
        guard let verse = pendingVerseDelete else { return }
        let count = sortedVerses.count
        modelContext.delete(verse)
        try? modelContext.save()
        pendingVerseDelete = nil
        if currentIndex >= count - 1 {
            currentIndex = max(0, count - 2)
        }
    }

    private func markPackAccess() {
        pack.lastAccessedAt = Date()
        try? modelContext.save()
    }

    private func applyInitialVerseFocusIfNeeded() {
        guard !didApplyInitialVerseFocus, let initialVerseID else { return }
        let verses = sortedVerses
        guard let index = verses.firstIndex(where: { $0.id == initialVerseID }) else {
            didApplyInitialVerseFocus = true
            return
        }
        currentIndex = index
        didApplyInitialVerseFocus = true
    }

    // MARK: Empty / No Results

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 120)

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
            LinearGradient(
                colors: [Color.neuBg.opacity(0), Color.neuBg.opacity(0.85), Color.neuBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            HStack(spacing: 16) {
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

                Button {
                    showAddVerse = true
                } label: {
                    ZStack {
                        NeuRaised(
                            shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                            radius: 8,
                            distance: 6
                        )
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                    }
                    .frame(width: 50, height: 50)
                }
                .buttonStyle(.plain)

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
            .padding(.bottom, 120)
            .background(Color.neuBg)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Swipe Action Circle

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

// MARK: - Neumorphic Add Verse Sheet

private struct NeuAddVerseSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Bindable var pack: Pack
    @Binding var isPresented: Bool
    @State private var reference = ""
    @State private var text = ""
    @FocusState private var focusedField: Field?

    private enum Field { case reference, text }

    private var canSave: Bool {
        !reference.trimmingCharacters(in: .whitespaces).isEmpty &&
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    NeuCircleButton(icon: "xmark") {
                        isPresented = false
                    }

                    Spacer()

                    Text("Add Verse")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                    Spacer()

                    Button {
                        save()
                    } label: {
                        ZStack {
                            NeuRaised(shape: Capsule(), radius: 6, distance: 5)
                            Text("Save")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(canSave
                                    ? (colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                                    : (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reference")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))

                            ZStack {
                                NeuInset(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                TextField("e.g. John 3:16", text: $reference)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .focused($focusedField, equals: .reference)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Verse Text")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))

                            ZStack(alignment: .topLeading) {
                                NeuInset(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                TextField("Enter the verse text...", text: $text, axis: .vertical)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                                    .lineLimit(5...15)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .focused($focusedField, equals: .text)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { focusedField = .reference }
    }

    private func save() {
        let order = pack.verses.count
        let verse = Verse(
            reference: reference.trimmingCharacters(in: .whitespaces),
            text: text.trimmingCharacters(in: .whitespaces),
            order: order
        )
        verse.pack = pack
        modelContext.insert(verse)
        try? modelContext.save()
        isPresented = false
    }
}

// MARK: - Neumorphic Toggle

private struct NeuToggle: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isOn: Bool

    private let width: CGFloat = 56
    private let height: CGFloat = 30
    private let inset: CGFloat = 3

    private var pillSize: CGFloat { height - inset * 2 }

    var body: some View {
        ZStack {
            // Inset track
            NeuInset(shape: Capsule())

            // Green fill with emissive glow
            ZStack {
                Capsule()
                    .fill(Color(red: 0.3, green: 0.78, blue: 0.4).opacity(isOn ? 0.4 : 0))
                    .blur(radius: 6)
                Capsule()
                    .fill(Color(red: 0.3, green: 0.78, blue: 0.4).opacity(isOn ? (colorScheme == .dark ? 0.5 : 0.6) : 0))
                    .padding(2)
            }
            .animation(.easeOut(duration: 0.15), value: isOn)

            // Raised pill
            Capsule()
                .fill(Color.neuBg)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.18), radius: 3, x: 2, y: 2)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.07 : 0.6), radius: 3, x: -1, y: -1)
                .frame(width: pillSize, height: pillSize)
                .offset(x: isOn ? (width / 2 - pillSize / 2 - inset) : -(width / 2 - pillSize / 2 - inset))
                .animation(.easeOut(duration: 0.15), value: isOn)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .onTapGesture {
            isOn.toggle()
        }
    }
}

// MARK: - Pack Options Sheet

private struct PackOptionsSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    @Binding var showBackReference: Bool
    var onEditPack: () -> Void
    var onDeletePack: () -> Void

    var body: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    NeuCircleButton(icon: "xmark") {
                        isPresented = false
                    }
                    Spacer()
                    Text("Options")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                    Spacer()
                    // Invisible spacer to balance the X button
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                VStack(spacing: 16) {
                    // Show reference toggle
                    ZStack {
                        NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Reference on Verse")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                                Text("Display the reference below the verse text")
                                    .font(.system(size: 12))
                                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                            }
                            Spacer()
                            NeuToggle(isOn: $showBackReference)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                    }
                    .frame(height: 64)

                    // Edit pack button
                    Button(action: {
                        isPresented = false
                        onEditPack()
                    }) {
                        ZStack {
                            NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))
                            HStack {
                                Image(systemName: "pencil")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Edit Pack")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.25))
                            }
                            .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                        }
                        .frame(height: 52)
                    }
                    .buttonStyle(.plain)

                    // Delete pack button
                    Button(action: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDeletePack()
                        }
                    }) {
                        ZStack {
                            NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Delete Pack")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                            }
                            .foregroundStyle(.red.opacity(0.7))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                        }
                        .frame(height: 52)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
    .modelContainer(for: [Pack.self, Verse.self, ReviewEvent.self, ReviewRecord.self], inMemory: true)
}
