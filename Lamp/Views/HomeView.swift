import SwiftUI
import SwiftData

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var packs: [Pack]
    @Query private var verses: [Verse]

    private var totalPacks: Int { packs.count }
    private var totalVerses: Int { verses.count }

    // MARK: Computed Properties

    private var overallHealth: Double {
        let healthValues = verses.compactMap(\.memoryHealth)
        guard !healthValues.isEmpty else { return 0 }
        return healthValues.reduce(0, +) / Double(healthValues.count)
    }

    private var reviewedDaySet: Set<Date> {
        Set(verses.compactMap(\.lastReviewed).map { Calendar.current.startOfDay(for: $0) })
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard !reviewedDaySet.isEmpty else { return 0 }
        var anchor = today
        if !reviewedDaySet.contains(today) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
                  reviewedDaySet.contains(yesterday) else { return 0 }
            anchor = yesterday
        }
        var streak = 0
        var cursor = anchor
        while reviewedDaySet.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private var heatmapDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<30).compactMap { cal.date(byAdding: .day, value: -(29 - $0), to: today) }
    }

    private var reviewsThisWeek: Int {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
        return reviewedDaySet.filter { $0 >= weekStart && $0 < weekEnd }.count
    }

    private var weakestVerses: [Verse] {
        verses
            .filter { $0.memoryHealth != nil }
            .sorted { ($0.memoryHealth ?? 1) < ($1.memoryHealth ?? 1) }
            .prefix(3)
            .map { $0 }
    }

    // MARK: Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {

                // Title
                Text("Home")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                // Stats row
                HStack(spacing: 12) {
                    statChip(value: "\(totalPacks)", label: "Packs")
                    statChip(value: "\(totalVerses)", label: "Verses")
                    statChip(value: "\(currentStreak) day", label: "Streak")
                }
                .padding(.horizontal, 20)

                // AMH ring + label
                VStack(spacing: 6) {
                    HomeAMHRing(progress: overallHealth)
                        .padding(.vertical, 16)

                    HStack(spacing: 4) {
                        Text("% Average memory health")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                // Bottom cards row
                HStack(alignment: .top, spacing: 14) {
                    HeatmapCard(
                        heatmapDays: heatmapDays,
                        reviewedDaySet: reviewedDaySet,
                        reviewsThisWeek: reviewsThisWeek
                    )
                    NeedsAttentionCard(verses: weakestVerses)
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.neuBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Stat Chip

    private func statChip(value: String, label: String) -> some View {
        ZStack {
            NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 68)
    }
}

// MARK: - AMH Ring

private struct HomeAMHRing: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double

    private let ringDiameter: CGFloat = 190
    private let ringWidth: CGFloat = 24

    private var ringColor: Color {
        if progress >= 0.75 {
            return Color(red: 0.55, green: 0.78, blue: 0.95)
        }
        let t = max(0, progress / 0.75)
        return Color(
            red: 0.9 + 0.05 * t,
            green: 0.3 + 0.5 * t,
            blue: 0.25 + 0.05 * t
        )
    }

    var body: some View {
        ZStack {
            // MARK: Raised ring (torus)
            Circle()
                .stroke(Color.neuBg, lineWidth: ringWidth)
                .frame(width: ringDiameter, height: ringDiameter)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    radius: 5, x: 6, y: 6
                )
                .shadow(
                    color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7),
                    radius: 5, x: -3, y: -3
                )

            // MARK: Progress arc (painted on top of ring)
            // Outer glow
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor.opacity(0.35),
                    style: StrokeStyle(lineWidth: ringWidth + 6, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .blur(radius: 6)
                .rotationEffect(.degrees(-90))

            // Fillet layer — slightly wider and softened to blend into the ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor.opacity(0.5),
                    style: StrokeStyle(lineWidth: ringWidth + 2, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .blur(radius: 3)
                .rotationEffect(.degrees(-90))

            // Solid color arc with cylindrical shading
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            ringColor.opacity(0.7),
                            ringColor,
                            ringColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringWidth - 4, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 1, y: 1)
                .shadow(color: Color.white.opacity(0.3), radius: 2, x: -0.5, y: -0.5)
                .rotationEffect(.degrees(-90))

            // MARK: Center text
            Text("\(Int(progress * 100))")
                .font(.system(size: 88, weight: .heavy, design: .default))
                .foregroundStyle(
                    colorScheme == .dark
                        ? Color.white.opacity(0.3)
                        : Color.black.opacity(0.18)
                )
                .shadow(
                    color: Color.white.opacity(colorScheme == .dark ? 0.06 : 0.75),
                    radius: 0, x: 1.5, y: 1.5
                )
        }
        .frame(width: ringDiameter + ringWidth + 24, height: ringDiameter + ringWidth + 24)
    }
}

// MARK: - Heatmap Card

private struct HeatmapCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let heatmapDays: [Date]
    let reviewedDaySet: Set<Date>
    let reviewsThisWeek: Int

    private let cols = 6
    private let rows = 5
    private let dotSize: CGFloat = 7
    private let dotSpacing: CGFloat = 5

    var body: some View {
        ZStack(alignment: .topLeading) {
            NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("Last 30 days")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))

                heatmapGrid

                Text("\(reviewsThisWeek)/7 this week")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    private var heatmapGrid: some View {
        VStack(spacing: dotSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: dotSpacing) {
                    ForEach(0..<cols, id: \.self) { col in
                        let index = row * cols + col
                        if index < heatmapDays.count {
                            let day = heatmapDays[index]
                            let reviewed = reviewedDaySet.contains(day)
                            Circle()
                                .fill(
                                    reviewed
                                        ? Color(red: 0.55, green: 0.78, blue: 0.95).opacity(0.85)
                                        : (colorScheme == .dark
                                           ? Color.white.opacity(0.08)
                                           : Color.black.opacity(0.08))
                                )
                                .frame(width: dotSize, height: dotSize)
                        } else {
                            Color.clear.frame(width: dotSize, height: dotSize)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Needs Attention Card

private struct NeedsAttentionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let verses: [Verse]

    var body: some View {
        ZStack(alignment: .topLeading) {
            NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))

            if verses.isEmpty {
                emptyState
            } else {
                verseList
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    private var verseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Needs attention")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))

            VStack(spacing: 8) {
                ForEach(verses, id: \.id) { verse in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(healthColor(for: verse.memoryHealth ?? 0))
                            .frame(width: 6, height: 6)
                        Text(verse.reference)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.6))
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int((verse.memoryHealth ?? 0) * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                    }
                }
            }
        }
        .padding(14)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(red: 0.55, green: 0.78, blue: 0.95).opacity(0.7))
            Text("All verses\nin great shape")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }

    private func healthColor(for health: Double) -> Color {
        if health >= 0.75 { return Color(red: 0.55, green: 0.78, blue: 0.95) }
        let t = max(0, health / 0.75)
        return Color(
            red: 0.9 + 0.05 * t,
            green: 0.3 + 0.5 * t,
            blue: 0.25 + 0.05 * t
        )
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Pack.self, Verse.self, configurations: config)

    let pack = Pack(title: "Psalms")
    container.mainContext.insert(pack)

    let cal = Calendar.current
    let today = Date()

    let sampleVerses: [(String, String, Double, Int)] = [
        ("Psalm 23:1",  "The Lord is my shepherd; I shall not want.",      0.88, 0),
        ("John 3:16",   "For God so loved the world...",                   0.42, 1),
        ("Romans 8:28", "And we know that in all things God works for good", 0.31, 2),
        ("Phil 4:13",   "I can do all things through Christ who strengthens me", 0.65, 3),
        ("Prov 3:5",    "Trust in the Lord with all your heart...",        0.19, 4),
    ]

    for (i, (ref, text, health, order)) in sampleVerses.enumerated() {
        let daysAgo = [0, 1, 2, 4, 6][i]
        let reviewed = cal.date(byAdding: .day, value: -daysAgo, to: today)
        let verse = Verse(reference: ref, text: text, order: order, lastReviewed: reviewed, memoryHealth: health)
        verse.pack = pack
        container.mainContext.insert(verse)
    }

    for d in [3, 5, 7, 9, 11, 13, 16, 19, 22, 25, 28] {
        let v = Verse(
            reference: "Gen 1:\(d)",
            text: "Sample verse text.",
            order: 10 + d,
            lastReviewed: cal.date(byAdding: .day, value: -d, to: today),
            memoryHealth: nil
        )
        v.pack = pack
        container.mainContext.insert(v)
    }

    return NavigationStack {
        HomeView()
    }
    .modelContainer(container)
}
