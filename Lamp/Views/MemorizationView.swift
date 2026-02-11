import SwiftUI
import SwiftData

struct MemorizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let verses: [Verse]
    let pack: Pack?
    @State private var currentIndex: Int = 0
    @State private var isRevealed = false

    private var currentVerse: Verse? {
        guard verses.indices.contains(currentIndex) else { return nil }
        return verses[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                Spacer()
                Text("\(currentIndex + 1)/\(verses.count)")
                    .font(.headline)
                Spacer()
                Button {
                    markGotIt()
                    advance()
                } label: {
                    Image(systemName: "checkmark")
                }
            }
            .padding()

            if let verse = currentVerse {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verse.reference)
                        .font(.headline)
                    if isRevealed {
                        Text(verse.text)
                            .font(.body)
                    } else {
                        Text("Tap to reveal")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .onTapGesture {
                    withAnimation { isRevealed = true }
                }
                .glassEffect()
                .padding()

                HStack(spacing: 24) {
                    Button {
                        if currentIndex > 0 {
                            currentIndex -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.glass)
                    .disabled(currentIndex == 0)

                    Spacer()

                    Button("Skip") {
                        advance()
                    }
                    .buttonStyle(.glass)

                    Spacer()

                    Button {
                        if currentIndex < verses.count - 1 {
                            currentIndex += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.glass)
                    .disabled(currentIndex >= verses.count - 1)
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "No verses to review",
                    systemImage: "book.closed",
                    description: Text(verses.isEmpty ? "Add verses to this pack to start memorizing." : "You've finished this session.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            isRevealed = false
            if verses.isEmpty {
                dismiss()
            }
        }
        .onChange(of: currentIndex) { _, _ in
            isRevealed = false
        }
    }

    private func markGotIt() {
        guard let verse = currentVerse else { return }
        verse.lastReviewed = Date()
        let current = verse.memoryHealth ?? 0
        verse.memoryHealth = min(1, current + 0.1)
        try? modelContext.save()
    }

    private func advance() {
        if currentIndex < verses.count - 1 {
            currentIndex += 1
        } else {
            dismiss()
        }
    }
}

#Preview {
    MemorizationView(
        verses: [
            Verse(reference: "John 3:16", text: "For God so loved the world...", order: 0)
        ],
        pack: nil
    )
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
