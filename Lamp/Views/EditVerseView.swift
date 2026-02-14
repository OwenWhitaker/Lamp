import SwiftUI
import SwiftData

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

#Preview {
    EditVerseView(
        isPresented: .constant(true),
        verse: Verse(reference: "John 3:16", text: "For God so loved the world...", order: 0)
    )
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
