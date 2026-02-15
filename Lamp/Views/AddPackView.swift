import SwiftUI
import SwiftData

private let neuBg = Color(red: 40 / 255, green: 40 / 255, blue: 50 / 255)

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
                            .fill(neuBg)
                            .shadow(color: Color.black.opacity(0.4), radius: 4, x: 2, y: 2)
                            .shadow(color: Color.white.opacity(0.08), radius: 4, x: -1, y: -1)
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
                            .fill(canCreate ? Color.accentColor : neuBg)
                            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 4, y: 4)
                            .shadow(color: Color.white.opacity(0.08), radius: 6, x: -2, y: -2)
                    )
                    .foregroundStyle(canCreate ? .white : Color.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
            .padding()
            .background(neuBg.ignoresSafeArea())
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
