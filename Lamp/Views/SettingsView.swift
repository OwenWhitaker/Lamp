import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
                // Title
                Text("Settings")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                // Appearance section
                VStack(spacing: 16) {
                    Text("Appearance")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    appearancePicker
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.neuBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Appearance Picker

    private var appearancePicker: some View {
        ZStack {
            NeuInset(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))
                .frame(height: 56)

            HStack(spacing: 8) {
                ForEach(AppearanceOption.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            appearanceMode = option.rawValue
                        }
                    } label: {
                        ZStack {
                            if appearanceMode == option.rawValue {
                                NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner - 4, style: .continuous), radius: 6, distance: 5)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 13, weight: .medium))
                                Text(option.label)
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                            }
                            .foregroundStyle(
                                appearanceMode == option.rawValue
                                    ? (colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                                    : (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .frame(height: 56)
        }
    }
}

// MARK: - Appearance Option

private enum AppearanceOption: Int, CaseIterable, Identifiable {
    case system = 0, light = 1, dark = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
