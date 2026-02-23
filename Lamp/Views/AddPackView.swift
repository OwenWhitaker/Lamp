import SwiftUI
import SwiftData

struct AddPackView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var selectedAccentIndex: Int? = nil

    private let accentPalette: [Color] = [
        Color(red: 0.94, green: 0.56, blue: 0.33), // orange
        Color(red: 0.37, green: 0.67, blue: 0.96), // blue
        Color(red: 0.38, green: 0.79, blue: 0.60), // mint
        Color(red: 0.82, green: 0.52, blue: 0.96), // violet
        Color(red: 0.62, green: 0.56, blue: 0.94)  // indigo
    ]

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func createPack() {
        guard canCreate else { return }
        let pack = Pack(
            title: title.trimmingCharacters(in: .whitespaces),
            accentIndex: selectedAccentIndex
        )
        modelContext.insert(pack)
        try? modelContext.save()
        isPresented = false
    }

    var body: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("New Pack")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                    .padding(.top, 8)

                ZStack(alignment: .leading) {
                    NeuInset(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    TextField("Pack Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.64))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .frame(height: 48)

                Text("Pick a pack color")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.48) : Color.black.opacity(0.44))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                    ForEach(0..<(accentPalette.count + 1), id: \.self) { slot in
                        let isBlank = slot == 0
                        let paletteIndex = slot - 1
                        let isSelected = isBlank ? (selectedAccentIndex == -1) : (selectedAccentIndex == paletteIndex)

                        Button {
                            selectedAccentIndex = isBlank ? -1 : paletteIndex
                        } label: {
                            ZStack {
                                NeuRaised(shape: Circle(), radius: 6, distance: 5)
                                    .frame(width: 58, height: 58)

                                if isBlank {
                                    Circle()
                                        .fill(Color.neuBg)
                                        .frame(width: 32, height: 32)
                                    Circle()
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.25), lineWidth: 1.5)
                                        .frame(width: 32, height: 32)
                                } else {
                                    Circle()
                                        .fill(accentPalette[paletteIndex].opacity(colorScheme == .dark ? 0.9 : 0.8))
                                        .frame(width: 32, height: 32)
                                }

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.75))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)

                sheetButton(title: "Create") { createPack() }
                    .disabled(!canCreate)
                    .opacity(canCreate ? 1 : 0.55)

                sheetButton(title: "Cancel") { isPresented = false }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func sheetButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                NeuRaised(shape: RoundedRectangle(cornerRadius: 16, style: .continuous), radius: 8, distance: 8)
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.62))
            }
            .frame(height: 52)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddPackView(isPresented: .constant(true))
        .modelContainer(for: [Pack.self, Verse.self, ReviewEvent.self, ReviewRecord.self], inMemory: true)
}
