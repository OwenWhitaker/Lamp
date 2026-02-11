import SwiftUI
import SwiftData

struct AddPackView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @State private var title = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("Pack Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button("Create") {
                    guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let pack = Pack(title: title.trimmingCharacters(in: .whitespaces))
                    modelContext.insert(pack)
                    try? modelContext.save()
                    isPresented = false
                }
                .buttonStyle(.glass)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .navigationTitle("My Packs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    AddPackView(isPresented: .constant(true))
        .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
