import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Environment(\.dismiss) private var dismiss
    let pack: Pack
    let verses: [Verse]

    @State private var currentIndex: Int = 0
    @State private var isFlipped = false
    @State private var showSwipeToSort = false

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
                    TabView(selection: $currentIndex) {
                        ForEach(Array(verses.enumerated()), id: \.element.id) { index, verse in
                            flashcardFace(verse: verse)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentIndex) { _, _ in
                        isFlipped = false
                    }

                    HStack(spacing: 6) {
                        ForEach(Array(verses.enumerated()), id: \.element.id) { index, _ in
                            Circle()
                                .fill(index == currentIndex ? Color.primary : Color.primary.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.vertical, 16)

                    HStack(spacing: 12) {
                        Button("Memorization Tool") {
                            // Placeholder
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button("Swipe to sort") {
                            showSwipeToSort = true
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                        Button("Memorization Tool") {
                            // Placeholder
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    HStack(spacing: 32) {
                        Button {
                            if currentIndex > 0 {
                                withAnimation { currentIndex -= 1 }
                            }
                        } label: {
                            Image(systemName: "chevron.left.circle")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex == 0)

                        Button {
                            // Placeholder center action
                        } label: {
                            Image(systemName: "circle")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if currentIndex < verses.count - 1 {
                                withAnimation { currentIndex += 1 }
                            }
                        } label: {
                            Image(systemName: "chevron.right.circle")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentIndex >= verses.count - 1)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(pack.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
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

    private func flashcardFace(verse: Verse) -> some View {
        ZStack {
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
        }
        .padding(.horizontal, 24)
        .aspectRatio(1.4, contentMode: .fit)
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
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
