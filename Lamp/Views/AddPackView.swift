import SwiftUI
import SwiftData

struct AddPackView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @State private var title = ""

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func createPack() {
        guard canCreate else { return }
        let pack = Pack(title: title.trimmingCharacters(in: .whitespaces))
        modelContext.insert(pack)
        try? modelContext.save()
        isPresented = false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("Pack Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color(.separator), lineWidth: 1)
                            )
                    )

                Button {
                    createPack()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.largeTitle)
                        Text("Create")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canCreate ? Color.accentColor : Color(.tertiarySystemFill))
                    )
                    .foregroundStyle(canCreate ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
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
