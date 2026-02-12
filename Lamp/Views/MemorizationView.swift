import SwiftUI
import SwiftData

private let swipeThreshold: CGFloat = 80

struct MemorizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let verses: [Verse]
    let pack: Pack?
    @State private var currentIndex: Int = 0
    @State private var isRevealed = false
    @State private var showSessionSettings = false
    @State private var dragOffset: CGFloat = 0

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
                .buttonStyle(.bordered)
                Spacer()
                Text("\(currentIndex + 1)/\(verses.count)")
                    .font(.headline)
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        showSessionSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        markGotIt()
                        advance()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .sheet(isPresented: $showSessionSettings) {
                SessionSettingsPlaceholderView()
            }

            if let verse = currentVerse {
                ZStack {
                    Image(systemName: "xmark")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "checkmark")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(height: 44)
                .padding(.horizontal, 20)

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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(.separator), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .offset(x: dragOffset)
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
                                withAnimation(.spring(response: 0.3)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
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
            dragOffset = 0
        }
    }

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
    }

    private func advance() {
        if currentIndex < verses.count - 1 {
            currentIndex += 1
        } else {
            dismiss()
        }
    }
}

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

#Preview {
    MemorizationView(
        verses: [
            Verse(reference: "John 3:16", text: "For God so loved the world...", order: 0)
        ],
        pack: nil
    )
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
