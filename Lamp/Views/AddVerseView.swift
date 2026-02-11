import SwiftUI
import SwiftData

struct AddVerseView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var pack: Pack
    @Binding var isPresented: Bool
    @State private var reference = ""
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Reference", text: $reference, prompt: Text("e.g. John 3:16"))
                TextField("Verse text", text: $text, axis: .vertical)
                    .lineLimit(5...20)
            }
            .navigationTitle("Add Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(reference.trimmingCharacters(in: .whitespaces).isEmpty || text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
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

#Preview {
    AddVerseView(pack: Pack(title: "Preview"), isPresented: .constant(true))
        .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
