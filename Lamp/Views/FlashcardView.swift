import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Environment(\.dismiss) private var dismiss
    let pack: Pack
    let verses: [Verse]
    let initialVerseID: UUID?

    @State private var currentIndex: Int
    @State private var isFlipped = false
    @State private var showSwipeToSort = false

    init(pack: Pack, verses: [Verse], initialVerseID: UUID? = nil) {
        self.pack = pack
        self.verses = verses
        self.initialVerseID = initialVerseID
        let startIndex = initialVerseID.flatMap { id in
            verses.firstIndex(where: { $0.id == id })
        } ?? 0
        _currentIndex = State(initialValue: startIndex)
    }

    private var currentVerse: Verse? {
        guard verses.indices.contains(currentIndex) else { return nil }
        return verses[currentIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if verses.isEmpty {
                    ContentUnavailableView(
                        "No verses",
                        systemImage: "book.closed",
                        description: Text("Add verses to this pack to study.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeometryReader { geo in
                        let cardWidth = geo.size.width - 2 * VerseCardLayout.horizontalPadding
                        TabView(selection: $currentIndex) {
                            ForEach(Array(verses.enumerated()), id: \.element.id) { index, verse in
                                HStack(spacing: 0) {
                                    flashcardFace(verse: verse)
                                        .frame(width: cardWidth, height: VerseCardLayout.cardHeight)
                                    Spacer(minLength: 0)
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .onChange(of: currentIndex) { _, _ in
                            isFlipped = false
                        }
                    }
                    .frame(height: VerseCardLayout.cardHeight)

                    HStack(spacing: 6) {
                        ForEach(Array(verses.enumerated()), id: \.element.id) { index, _ in
                            Circle()
                                .fill(index == currentIndex ? Color.primary : Color.primary.opacity(0.2))
                                .frame(
                                    width: index == currentIndex ? 10 : 8,
                                    height: index == currentIndex ? 10 : 8
                                )
                        }
                    }
                    .padding(.vertical, 16)

                    VStack(spacing: 12) {
                        memorizationToolButton(icon: "xmark", label: "Memorization Tool") {
                            // Placeholder
                        }
                        memorizationToolButton(icon: "xmark", label: "Memorization Tool") {
                            showSwipeToSort = true
                        }
                        memorizationToolButton(icon: "xmark", label: "Memorization Tool") {
                            // Placeholder
                        }
                    }
                    .padding(.horizontal, VerseCardLayout.horizontalPadding)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    HStack(spacing: 6) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        Text(pack.title)
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Button {
                            // Share placeholder
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button {
                            // More placeholder
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showSwipeToSort) {
                MemorizationView(verses: verses, pack: pack)
            }
        }
    }

    private func memorizationToolButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.body)
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(.separator), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func flashcardFace(verse: Verse) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(.separator), lineWidth: 1)
                )

            Text(verse.reference)
                .font(.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()

            Text(verse.text)
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                isFlipped.toggle()
            }
        }
    }
}

#Preview {
    FlashcardView(
        pack: Pack(title: "Preview Pack"),
        verses: [
            Verse(reference: "John 3:16", text: "For God so loved the world...", order: 0),
            Verse(reference: "Psalm 23:1", text: "The Lord is my shepherd...", order: 1),
        ]
    )
    .modelContainer(for: [Pack.self, Verse.self, ReviewEvent.self, ReviewRecord.self], inMemory: true)
}
