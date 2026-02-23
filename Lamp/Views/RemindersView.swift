import SwiftUI
import SwiftData

// MARK: - RemindersView

struct RemindersView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.scheduledTime) private var reminders: [Reminder]
    @State private var sheetMode: ReminderSheetMode?

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
                sheetMode = .add
            })
            .padding(.bottom, 110)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.neuBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $sheetMode) { mode in
            AddReminderView(reminderID: mode.reminderID)
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

            Button {
                sheetMode = .edit(reminder.id)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.52) : Color.black.opacity(0.45))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.neuBg)
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14), radius: 2.8, x: 1.2, y: 1.2)
                            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.07 : 0.5), radius: 2.3, x: -0.9, y: -0.9)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)

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
            Button {
                sheetMode = .edit(reminder.id)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                deleteReminder(reminder)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formattedSchedule(_ reminder: Reminder) -> String {
        guard reminder.isDateEnabled else { return "No date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let time = formatter.string(from: reminder.scheduledTime)
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeText = reminder.isTimeEnabled ? timeFormatter.string(from: reminder.scheduledTime) : "All day"
        switch reminder.repeatFrequency {
        case .daily: return "Daily at \(timeText)"
        case .weekly:
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            let day = dayFormatter.string(from: reminder.scheduledTime)
            return "Every \(day) at \(timeText)"
        case .none: return "On \(time) at \(timeText)"
        }
    }

    private func deleteReminder(_ reminder: Reminder) {
        NotificationManager.cancelReminder(reminder)
        modelContext.delete(reminder)
    }
}

// MARK: - AddReminderView

private enum ReminderSheetMode: Identifiable {
    case add
    case edit(UUID)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let reminderID): return "edit-\(reminderID.uuidString)"
        }
    }

    var reminderID: UUID? {
        switch self {
        case .add: return nil
        case .edit(let reminderID): return reminderID
        }
    }
}

struct AddReminderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pack.createdAt) private var packs: [Pack]
    @Query(sort: \Reminder.createdAt, order: .reverse) private var reminders: [Reminder]

    let reminderID: UUID?

    @State private var reminderTitle = ""
    @State private var reminderNotes = ""
    @State private var reminderURL = ""
    @State private var selectedPack: Pack?
    @State private var scheduledTime = Date()
    @State private var repeatFrequency: RepeatFrequency = .daily
    @State private var isDateEnabled = true
    @State private var isTimeEnabled = true
    @State private var isUrgent = false

    private var reminderToEdit: Reminder? {
        guard let reminderID else { return nil }
        return reminders.first { $0.id == reminderID }
    }

    var body: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    header

                    reminderTextCard

                    sectionLabel("Date & Time")
                    dateTimeCard

                    Text("Mark this reminder as urgent to set an alarm-like alert.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.42) : Color.black.opacity(0.42))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    repeatCard
                    packCard

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .task(id: reminderID) {
            loadReminder()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            headerButton(icon: "xmark", fill: Color.neuBg) {
                dismiss()
            }

            Spacer()

            Text("Details")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.9 : 0.2))

            Spacer()

            headerButton(icon: "checkmark", fill: Color(red: 0.05, green: 0.63, blue: 0.98), iconColor: Color.white.opacity(0.92)) {
                save()
            }
        }
        .padding(.top, 12)
    }

    private func headerButton(icon: String, fill: Color, iconColor: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.16), radius: 6, x: 3, y: 3)
                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.07 : 0.5), radius: 5, x: -2, y: -2)
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(iconColor ?? (colorScheme == .dark ? Color.white.opacity(0.75) : Color.black.opacity(0.62)))
            }
            .frame(width: 68, height: 68)
        }
        .buttonStyle(.plain)
    }

    private var reminderTextCard: some View {
        panelCard {
            VStack(spacing: 0) {
                TextField("New Reminder", text: $reminderTitle)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.9 : 0.2))
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                Divider().opacity(0.12)

                TextField("Notes", text: $reminderNotes, axis: .vertical)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .lineLimit(3)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.55))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)

                Divider().opacity(0.12)

                TextField("URL", text: $reminderURL)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.55))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
        }
    }

    private var dateTimeCard: some View {
        panelCard {
            VStack(spacing: 0) {
                toggleRow(
                    icon: "calendar",
                    title: "Date",
                    subtitle: isDateEnabled
                        ? scheduledTime.formatted(date: .abbreviated, time: .omitted)
                        : "Off",
                    isOn: $isDateEnabled
                )

                Divider().opacity(0.12).padding(.leading, 58)

                toggleRow(
                    icon: "clock",
                    title: "Time",
                    subtitle: isTimeEnabled
                        ? scheduledTime.formatted(date: .omitted, time: .shortened)
                        : "Off",
                    isOn: $isTimeEnabled
                )
                .disabled(!isDateEnabled)
                .opacity(isDateEnabled ? 1 : 0.45)

                Divider().opacity(0.12).padding(.leading, 58)

                toggleRow(
                    icon: "alarm",
                    title: "Urgent",
                    subtitle: isUrgent ? "On" : "Off",
                    isOn: $isUrgent
                )
                .disabled(!isDateEnabled)
                .opacity(isDateEnabled ? 1 : 0.45)

                if isDateEnabled {
                    Divider().opacity(0.12).padding(.leading, 18)
                    dateTimePicker
                }
            }
        }
    }

    private var dateTimePicker: some View {
        VStack(spacing: 10) {
            DatePicker("Date", selection: $scheduledTime, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(Color(red: 0.05, green: 0.63, blue: 0.98))
                .disabled(!isDateEnabled)

            if isTimeEnabled {
                DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .tint(Color(red: 0.05, green: 0.63, blue: 0.98))
            }
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.45))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.72))
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.05, green: 0.63, blue: 0.98))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(title == "Urgent" ? .orange : .green)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var repeatCard: some View {
        panelCard {
            HStack {
                Image(systemName: "repeat")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.45))

                Text("Repeat")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.72))

                Spacer()

                Menu {
                    ForEach(RepeatFrequency.allCases, id: \.self) { frequency in
                        Button(frequency.rawValue) {
                            repeatFrequency = frequency
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(repeatFrequency.rawValue)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    private var packCard: some View {
        panelCard {
            HStack {
                Image(systemName: "square.stack")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.45))

                Text("Pack")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.72))

                Spacer()

                Picker("Pack", selection: $selectedPack) {
                    Text("None").tag(Pack?.none)
                    ForEach(packs) { pack in
                        Text(pack.title).tag(Optional(pack))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    private func panelCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.neuBg.opacity(colorScheme == .dark ? 0.92 : 0.98),
                            Color.neuBg.opacity(colorScheme == .dark ? 0.72 : 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.14), radius: 10, x: 5, y: 6)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.06 : 0.5), radius: 7, x: -3, y: -3)
            content()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func loadReminder() {
        guard let reminder = reminderToEdit else {
            if reminderTitle.isEmpty {
                reminderTitle = ""
                reminderNotes = ""
                reminderURL = ""
                selectedPack = nil
                scheduledTime = Date()
                repeatFrequency = .daily
                isDateEnabled = true
                isTimeEnabled = true
                isUrgent = false
            }
            return
        }

        reminderTitle = reminder.title
        reminderNotes = reminder.notes
        reminderURL = reminder.urlString
        selectedPack = reminder.pack
        scheduledTime = reminder.scheduledTime
        repeatFrequency = reminder.repeatFrequency
        isDateEnabled = reminder.isDateEnabled
        isTimeEnabled = reminder.isTimeEnabled
        isUrgent = reminder.isUrgent
    }

    private func save() {
        let trimmedTitle = reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = selectedPack.map { "Review: \($0.title)" } ?? "Time to review!"
        let finalTitle = trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle
        let finalRepeat = isDateEnabled ? repeatFrequency : .none
        let finalEnabled = isDateEnabled

        if let reminder = reminderToEdit {
            reminder.title = finalTitle
            reminder.notes = reminderNotes
            reminder.urlString = reminderURL
            reminder.scheduledTime = scheduledTime
            reminder.repeatFrequency = finalRepeat
            reminder.isDateEnabled = isDateEnabled
            reminder.isTimeEnabled = isTimeEnabled
            reminder.isUrgent = isUrgent
            reminder.pack = selectedPack
            reminder.isEnabled = finalEnabled
            NotificationManager.cancelReminder(reminder)
            if finalEnabled {
                NotificationManager.requestPermission()
                NotificationManager.scheduleReminder(reminder)
            }
        } else {
            let reminder = Reminder(
                title: finalTitle,
                notes: reminderNotes,
                urlString: reminderURL,
                scheduledTime: scheduledTime,
                repeatFrequency: finalRepeat,
                isEnabled: finalEnabled,
                isDateEnabled: isDateEnabled,
                isTimeEnabled: isTimeEnabled,
                isUrgent: isUrgent,
                pack: selectedPack
            )
            modelContext.insert(reminder)
            if finalEnabled {
                NotificationManager.requestPermission()
                NotificationManager.scheduleReminder(reminder)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RemindersView()
    }
    .modelContainer(for: [Pack.self, Verse.self, ReviewEvent.self, ReviewRecord.self, Reminder.self], inMemory: true)
}
