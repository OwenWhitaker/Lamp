import SwiftUI
import SwiftData

// MARK: - RemindersView

struct RemindersView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.scheduledTime) private var reminders: [Reminder]
    @Query(sort: \Pack.createdAt) private var packs: [Pack]
    @State private var showAddReminder = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Title
                    Text("Reminders")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                    if reminders.isEmpty {
                        emptyState
                    } else {
                        reminderList
                    }

                    Spacer().frame(height: 120)
                }
            }

            // Floating add button
            NeuCircleButton(icon: "plus", size: 48, action: {
                showAddReminder = true
            })
            .padding(.bottom, 110)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.neuBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddReminder) {
            AddReminderView(isPresented: $showAddReminder)
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.5 : 0.45))
            Text("No reminders yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.7 : 0.35))
            Text("Tap + to create a reminder\nto stay on track with your memorization.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.5 : 0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }

    // MARK: Reminder List

    private var reminderList: some View {
        VStack(spacing: 14) {
            ForEach(reminders) { reminder in
                reminderCard(reminder)
            }
        }
        .padding(.horizontal, 20)
    }

    private func reminderCard(_ reminder: Reminder) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                Text(formattedSchedule(reminder))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.5 : 0.5))
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { newValue in
                    reminder.isEnabled = newValue
                    if newValue {
                        NotificationManager.scheduleReminder(reminder)
                    } else {
                        NotificationManager.cancelReminder(reminder)
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(16)
        .background(NeuRaised(shape: RoundedRectangle(cornerRadius: 16)))
        .contextMenu {
            Button(role: .destructive) {
                deleteReminder(reminder)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formattedSchedule(_ reminder: Reminder) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let time = formatter.string(from: reminder.scheduledTime)
        switch reminder.repeatFrequency {
        case .daily: return "Daily at \(time)"
        case .weekly:
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let day = dayFormatter.string(from: reminder.scheduledTime)
            return "Every \(day) at \(time)"
        case .none: return "Once at \(time)"
        }
    }

    private func deleteReminder(_ reminder: Reminder) {
        NotificationManager.cancelReminder(reminder)
        modelContext.delete(reminder)
    }
}

// MARK: - AddReminderView

struct AddReminderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @Query(sort: \Pack.createdAt) private var packs: [Pack]

    @State private var selectedPack: Pack?
    @State private var scheduledTime = Date()
    @State private var repeatFrequency: RepeatFrequency = .daily

    var body: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Text("New Reminder")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                        .padding(.top, 12)

                    // Pack picker
                    sectionLabel("Pack")
                    ZStack {
                        NeuInset(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Picker("Select a pack", selection: $selectedPack) {
                            Text("None").tag(Pack?.none)
                            ForEach(packs) { pack in
                                Text(pack.title).tag(Optional(pack))
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 10)
                    }
                    .frame(height: 48)

                    // Time picker
                    sectionLabel("Time")
                    ZStack {
                        NeuInset(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        DatePicker("", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    .frame(height: 48)

                    // Repeat frequency
                    sectionLabel("Repeat")
                    HStack(spacing: 12) {
                        ForEach(RepeatFrequency.allCases, id: \.self) { freq in
                            Button {
                                repeatFrequency = freq
                            } label: {
                                ZStack {
                                    if repeatFrequency == freq {
                                        NeuRaised(shape: RoundedRectangle(cornerRadius: 14, style: .continuous), radius: 6, distance: 5)
                                    } else {
                                        NeuInset(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    Text(freq.rawValue)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.62))
                                }
                                .frame(height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer().frame(height: 8)

                    sheetButton(title: "Save") { save() }
                    sheetButton(title: "Cancel") { isPresented = false }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func save() {
        let title: String
        if let pack = selectedPack {
            title = "Review: \(pack.title)"
        } else {
            title = "Time to review!"
        }

        let reminder = Reminder(
            title: title,
            scheduledTime: scheduledTime,
            repeatFrequency: repeatFrequency,
            pack: selectedPack
        )

        modelContext.insert(reminder)
        NotificationManager.requestPermission()
        NotificationManager.scheduleReminder(reminder)
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RemindersView()
    }
    .modelContainer(for: [Pack.self, Verse.self, Reminder.self], inMemory: true)
}
