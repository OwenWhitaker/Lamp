import SwiftUI
import SwiftData

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
#if DEBUG
    @State private var debugStatus: String = ""
    @State private var isRunningDataTask = false
#endif

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

#if DEBUG
                VStack(spacing: 16) {
                    Text("Developer")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    debugDataControls

                    if !debugStatus.isEmpty {
                        Text(debugStatus)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
#endif

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

#if DEBUG
    private var debugDataControls: some View {
        VStack(spacing: 10) {
            debugActionButton(
                title: "Generate Fake Usage Data",
                systemImage: "chart.xyaxis.line"
            ) {
                generateFakeUsageData()
            }
            .disabled(isRunningDataTask)

            debugActionButton(
                title: "Clear Usage Data",
                systemImage: "trash"
            ) {
                clearUsageData()
            }
            .disabled(isRunningDataTask)
        }
    }

    private func debugActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                NeuRaised(shape: RoundedRectangle(cornerRadius: 14, style: .continuous), radius: 6, distance: 5)
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.68) : Color.black.opacity(0.62))
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    private func clearUsageData() {
        guard !isRunningDataTask else { return }
        isRunningDataTask = true
        defer { isRunningDataTask = false }

        do {
            try clearUsageDataInternal()
            debugStatus = "Cleared all packs, verses, and review history."
        } catch {
            debugStatus = "Failed to clear usage data: \(error.localizedDescription)"
        }
    }

    private func generateFakeUsageData() {
        guard !isRunningDataTask else { return }
        isRunningDataTask = true
        defer { isRunningDataTask = false }

        do {
            try clearUsageDataInternal()

            let calendar = Calendar.current
            let now = Date()
            let today = calendar.startOfDay(for: now)

            let packSeeds: [(title: String, baseBook: String)] = [
                ("Foundations", "Psalm"),
                ("Core Gospel", "John"),
                ("Wisdom Stack", "Proverbs"),
                ("Pauline Picks", "Romans"),
                ("Promises", "Isaiah")
            ]

            var generatedVerses: [Verse] = []
            var generatedPacks: [Pack] = []

            for (index, seed) in packSeeds.enumerated() {
                let packAgeDays = Int.random(in: 40...220)
                let packCreatedAt = calendar.date(byAdding: .day, value: -packAgeDays, to: today) ?? today
                let pack = Pack(
                    title: seed.title,
                    createdAt: packCreatedAt,
                    lastAccessedAt: nil,
                    accentIndex: index
                )
                modelContext.insert(pack)
                generatedPacks.append(pack)

                let verseCount = Int.random(in: 12...26)
                let span = max(1, min(packAgeDays, 90))

                for order in 0..<verseCount {
                    let chapter = Int.random(in: 1...28)
                    let line = Int.random(in: 1...34)
                    let reference = "\(seed.baseBook) \(chapter):\(line)"
                    let verseCreatedAt = calendar.date(byAdding: .day, value: -Int.random(in: 0...span), to: today) ?? packCreatedAt
                    let verse = Verse(
                        reference: reference,
                        text: "Sample verse text for \(reference).",
                        order: order,
                        createdAt: verseCreatedAt,
                        memoryHealth: Double.random(in: 0.2...0.92)
                    )
                    verse.pack = pack
                    modelContext.insert(verse)
                    generatedVerses.append(verse)
                }
            }

            let simulatedDays = 140
            let maxDailyReviews = max(6, generatedVerses.count / 2)
            for dayOffset in 0..<simulatedDays {
                guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

                let activityChance: Double
                switch dayOffset {
                case 0...14: activityChance = 0.9
                case 15...45: activityChance = 0.72
                case 46...90: activityChance = 0.54
                default: activityChance = 0.38
                }
                if Double.random(in: 0...1) > activityChance { continue }

                let dailyReviews = Int.random(in: 1...maxDailyReviews)
                let sampledVerses = Array(generatedVerses.shuffled().prefix(dailyReviews))
                for verse in sampledVerses {
                    let reviewedAt = calendar.date(
                        bySettingHour: Int.random(in: 6...22),
                        minute: Int.random(in: 0...59),
                        second: Int.random(in: 0...59),
                        of: day
                    ) ?? day
                    verse.logReview(at: reviewedAt, in: modelContext)

                    let baseline = verse.memoryHealth ?? 0.45
                    let adjustment = Double.random(in: -0.08...0.1)
                    verse.memoryHealth = min(1, max(0, baseline + adjustment))
                }
            }

            for pack in generatedPacks {
                let mostRecent = generatedVerses
                    .filter { $0.pack?.id == pack.id }
                    .compactMap(\.lastReviewed)
                    .max()
                pack.lastAccessedAt = mostRecent
            }

            try modelContext.save()
            debugStatus = "Generated \(generatedPacks.count) packs, \(generatedVerses.count) verses, and realistic review history."
        } catch {
            debugStatus = "Failed to generate usage data: \(error.localizedDescription)"
        }
    }

    private func clearUsageDataInternal() throws {
        let records = try modelContext.fetch(FetchDescriptor<ReviewRecord>())
        for record in records {
            modelContext.delete(record)
        }

        let packs = try modelContext.fetch(FetchDescriptor<Pack>())
        for pack in packs {
            modelContext.delete(pack)
        }

        try modelContext.save()
    }
#endif
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
    .modelContainer(for: [Pack.self, Verse.self, ReviewEvent.self, ReviewRecord.self], inMemory: true)
}
