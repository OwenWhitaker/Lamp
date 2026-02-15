import SwiftUI
import SwiftData

private let neuBg = Color(UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(red: 40/255, green: 40/255, blue: 50/255, alpha: 1)
        : UIColor(red: 225/255, green: 225/255, blue: 235/255, alpha: 1)
})

struct AddPackView: View {
    @Environment(\.colorScheme) private var colorScheme
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
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 4, x: 2, y: 2)
                            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), radius: 4, x: -1, y: -1)
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
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 6, x: 4, y: 4)
                            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), radius: 6, x: -2, y: -2)
                    )
                    .foregroundStyle(canCreate ? .white : (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)))
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
