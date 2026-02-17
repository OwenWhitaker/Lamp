import SwiftUI
import SwiftData

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var packs: [Pack]
    @Query private var verses: [Verse]

    private var totalPacks: Int { packs.count }
    private var totalVerses: Int { verses.count }

    private var overallHealth: Double {
        let healthValues = verses.compactMap(\.memoryHealth)
        guard !healthValues.isEmpty else { return 0 }
        return healthValues.reduce(0, +) / Double(healthValues.count)
    }

    private var recentVerses: [Verse] {
        verses
            .filter { $0.lastReviewed != nil }
            .sorted { ($0.lastReviewed ?? .distantPast) > ($1.lastReviewed ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    private let shape = RoundedRectangle(cornerRadius: neuCorner, style: .continuous)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Title
                Text("Home")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                // Stats row
                HStack(spacing: 16) {
                    statCard(value: "\(totalPacks)", label: "Packs")
                    statCard(value: "\(totalVerses)", label: "Verses")
                    statCard(value: "\(Int(overallHealth * 100))%", label: "Memorized")
                }
                .padding(.horizontal, 20)

                // Progress ring
                VStack(spacing: 12) {
                    Text("Overall Progress")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        NeuInset(shape: Circle())
                            .frame(width: 140, height: 140)

                        ZStack {
                            Circle()
                                .stroke(lineWidth: 10)
                                .foregroundStyle(Color.clear)

                            Circle()
                                .trim(from: 0, to: overallHealth)
                                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.25))
                                .rotationEffect(.degrees(-90))

                            Text("\(Int(overallHealth * 100))%")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                        }
                        .frame(width: 110, height: 110)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)

                // Recent activity
                if !recentVerses.isEmpty {
                    VStack(spacing: 12) {
                        Text("Recently Reviewed")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            ForEach(recentVerses, id: \.id) { verse in
                                recentVerseRow(verse)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.neuBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Stat Card

    private func statCard(value: String, label: String) -> some View {
        ZStack {
            NeuRaised(shape: shape)

            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                Text(label)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
            }
        }
        .frame(height: 80)
    }

    // MARK: Recent Verse Row

    private func recentVerseRow(_ verse: Verse) -> some View {
        ZStack {
            NeuRaised(shape: shape, radius: 8, distance: 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verse.reference)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                    if let reviewed = verse.lastReviewed {
                        Text(reviewed, style: .relative)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                    }
                }
                Spacer()
                if let health = verse.memoryHealth {
                    Text("\(Int(health * 100))%")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 56)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
