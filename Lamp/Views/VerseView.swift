import SwiftUI
import SwiftData

struct VerseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var verse: Verse
    @State private var isRevealed = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .onTapGesture {
                    withAnimation { isRevealed.toggle() }
                }
                .glassEffect()

                VStack(spacing: 12) {
                    Button("Flashcard") {
                        withAnimation { isRevealed.toggle() }
                    }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)

                    Button("Memorization Tool 2") {
                        // Placeholder
                    }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)

                    Button("Memorization Tool 3") {
                        // Placeholder
                    }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle(verse.reference)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Verse", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete Verse", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(verse)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(verse.reference)\"?")
        }
    }
}

#Preview {
    NavigationStack {
        VerseView(verse: Verse(reference: "John 3:16", text: "For God so loved the world...", order: 0))
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
