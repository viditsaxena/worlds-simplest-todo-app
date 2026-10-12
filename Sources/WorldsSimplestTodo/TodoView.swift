import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

private enum TodoTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case oneOff = "One-off"
    case recurring = "Recurring"
    case birthdays = "Birthdays"

    var id: Self { self }
}

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @State private var draft = ""
    @State private var selectedTab: TodoTab = .today
    @State private var inputError: String?
    @State private var celebrationID: Int?
    @State private var celebrationSequence = 0
    @FocusState private var inputIsFocused: Bool

    private var showingRecurring: Bool {
        selectedTab == .recurring
    }

    private var showingToday: Bool {
        selectedTab == .today
    }

    private var showingBirthdays: Bool {
        selectedTab == .birthdays
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                tabs
                input

                if let inputError {
                    Text(inputError)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.top, 10)
                }

                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    if showingBirthdays {
                        if store.birthdays.isEmpty {
                            emptyState
                        } else {
                            birthdayList(at: timeline.date)
                        }
                    } else if !store.hasItems(
                        recurring: showingRecurring,
                        today: showingToday,
                        at: timeline.date
                    ) {
                        emptyState
                    } else {
                        taskList(at: timeline.date)
                    }
                }
            }

            if let celebrationID {
                CelebrationOverlay(burstID: celebrationID)
                    .id(celebrationID)
                    .transition(.opacity)
            }
        }
#if os(macOS)
        .frame(minWidth: 440, idealWidth: 520, minHeight: 480, idealHeight: 640)
#else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
#endif
        .background(Color.todoWindowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            inputIsFocused = true
        }
        .onAppear {
            focusInput()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusTodoInput)) { _ in
            selectedTab = .today
            inputError = nil
            focusInput()
        }
    }

    private var tabs: some View {
        Picker("To-do type", selection: $selectedTab) {
            ForEach(TodoTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(.background)
        .onChange(of: selectedTab) {
            inputError = nil
            focusInput()
        }
    }

    private var input: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(
                inputPlaceholder,
                text: $draft
            )
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .regular, design: .rounded))
                .focused($inputIsFocused)
                .onSubmit(addTask)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(.background)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()

            Text(emptyStateTitle)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(emptyStateSuggestion)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.tertiary)

#if os(macOS)
            Text("⌥N brings this window back anytime.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.tertiary)
#endif

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func taskList(at date: Date) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.sortedItems(
                    at: date,
                    recurring: showingRecurring,
                    today: showingToday
                )) { item in
                    taskRow(item, at: date)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func taskRow(_ item: TodoItem, at date: Date) -> some View {
        let isOverdue = item.isOverdue(at: date)

        return HStack(alignment: .top, spacing: 14) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    store.complete(item)
                }
                celebrate()
                focusInput()
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(isOverdue ? .red : .secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete " + item.title)

            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(isOverdue ? .red : .primary)
                    .multilineTextAlignment(.leading)

                if let recurrence = item.recurrence {
                    Label {
                        HStack(spacing: 4) {
                            if isOverdue {
                                Text("Overdue ·")
                                    .fontWeight(.bold)
                            }
                            Text(recurrence.scheduleDescription())
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isOverdue ? .red : .secondary)
                } else if let reminderDate = item.reminderDate {
                    Label {
                        HStack(spacing: 4) {
                            if isOverdue {
                                Text("Overdue ·")
                                    .fontWeight(.bold)
                            }
                            Text(reminderDate, format: .dateTime
                                .weekday(.wide)
                                .month(.abbreviated)
                                .day()
                                .hour()
                                .minute()
                            )
                        }
                    } icon: {
                        Image(systemName: "bell")
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isOverdue ? .red : .secondary)
                }

                if !item.isRecurring {
                    priorityControls(for: item)
                }
            }

            Spacer(minLength: 0)

            if item.isRecurring {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        store.delete(item)
                    }
                    focusInput()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete " + item.title)
                .todoHelp("Delete recurring reminder")
            } else if selectedTab == .oneOff {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        store.moveToToday(item)
                    }
                    focusInput()
                } label: {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Move " + item.title + " to Today")
                .todoHelp("Move to Today")
            } else if selectedTab == .today {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        store.moveToOneOff(item)
                    }
                    focusInput()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Move " + item.title + " back to One-off")
                .todoHelp("Move back to One-off")
            }
        }
        .padding(.leading, 28)
        .padding(.trailing, 16)
        .padding(.vertical, 15)
    }

    private func priorityControls(for item: TodoItem) -> some View {
        HStack(spacing: 6) {
            ForEach(TodoPriority.allCases) { priority in
                let isSelected = item.priority == priority
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        store.setPriority(priority, for: item)
                    }
                    focusInput()
                } label: {
                    Text(priority.shortTitle)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? priority.tint : .secondary)
                        .frame(minWidth: 11)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(isSelected
                                    ? priority.tint.opacity(0.14)
                                    : Color.secondary.opacity(0.08))
                        }
                        .overlay {
                            Capsule()
                                .stroke(
                                    isSelected ? priority.tint.opacity(0.55) : .clear,
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set \(item.title) priority to \(priority.title)")
            }
        }
    }

    private func birthdayList(at date: Date) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.sortedBirthdays(after: date)) { birthday in
                    birthdayRow(birthday, at: date)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func birthdayRow(_ birthday: BirthdayItem, at date: Date) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "birthday.cake")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.pink)

            VStack(alignment: .leading, spacing: 4) {
                Text(birthday.name)
                    .font(.system(size: 18, design: .rounded))

                Label {
                    Text(birthday.nextDate(after: date), format: .dateTime
                        .month(.wide)
                        .day()
                        .hour()
                        .minute()
                    )
                } icon: {
                    Image(systemName: "bell")
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    store.delete(birthday)
                }
                focusInput()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(birthday.name)'s birthday")
            .todoHelp("Delete birthday")
        }
        .padding(.leading, 28)
        .padding(.trailing, 16)
        .padding(.vertical, 15)
    }

    private var inputPlaceholder: String {
        switch selectedTab {
        case .oneOff:
            "What needs doing?"
        case .today:
            "What are you working on today?"
        case .recurring:
            "Pay rent on the first of every month at 9 am"
        case .birthdays:
            "Mum's birthday is March 12"
        }
    }

    private var emptyStateTitle: String {
        switch selectedTab {
        case .oneOff:
            "Type. Press return. Done."
        case .today:
            "Keep this list small."
        case .recurring:
            "Set it once. It comes back."
        case .birthdays:
            "Never miss a birthday."
        }
    }

    private var emptyStateSuggestion: String {
        switch selectedTab {
        case .oneOff:
            "Try “Call Mum tomorrow at 6 pm”"
        case .today:
            "Move a task here from One-off."
        case .recurring:
            "Try “Pay rent on the first of every month at 9 am”"
        case .birthdays:
            "Try “Mum's birthday is March 12 at 9 am”"
        }
    }

    private func addTask() {
        let title = draft
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            draft = ""
            return
        }

        if showingBirthdays {
            let birthday = store.addBirthday(title)
            guard birthday != nil else {
                inputError = "Include a name and date, such as “Mum's birthday is March 12.”"
                focusInput()
                return
            }

            inputError = nil
            draft = ""
            selectedTab = .birthdays
            focusInput()
            return
        }

        var addedItem: TodoItem?
        withAnimation(.easeOut(duration: 0.18)) {
            addedItem = store.add(
                title,
                requiresRecurrence: showingRecurring,
                isToday: showingToday
            )
        }

        guard let addedItem else {
            inputError = "Include a schedule, such as “on the first of every month at 9 am.”"
            focusInput()
            return
        }

        inputError = nil
        draft = ""
        if addedItem.isRecurring {
            selectedTab = .recurring
        } else {
            selectedTab = addedItem.isToday ? .today : .oneOff
        }
        focusInput()
    }

    private func focusInput() {
        DispatchQueue.main.async {
            inputIsFocused = true
        }
    }

    private func celebrate() {
        celebrationSequence += 1
        let currentID = celebrationSequence
        withAnimation(.easeOut(duration: 0.12)) {
            celebrationID = currentID
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.35))
            guard celebrationID == currentID else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                celebrationID = nil
            }
        }
    }
}

private extension Color {
    static var todoWindowBackground: Color {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }
}

private extension TodoPriority {
    var tint: Color {
        switch self {
        case .high: .red
        case .medium: .orange
        case .low: .secondary
        }
    }
}

private extension View {
    @ViewBuilder
    func todoHelp(_ text: String) -> some View {
#if os(macOS)
        help(text)
#else
        self
#endif
    }
}
