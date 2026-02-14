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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(.separator), lineWidth: 1)
                        )
                )

                VStack(spacing: 12) {
                    Button("Flashcard") {
                        withAnimation { isRevealed.toggle() }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Memorization Tool 2") {
                        // Placeholder
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Memorization Tool 3") {
                        // Placeholder
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle(verse.pack?.title ?? verse.reference)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Edit verse – placeholder
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
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
