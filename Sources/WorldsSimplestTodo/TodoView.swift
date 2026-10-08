import SwiftUI

private enum TodoTab: String, CaseIterable, Identifiable {
    case oneOff = "One-off"
    case today = "Today"
    case recurring = "Recurring"

    var id: Self { self }
}

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @State private var draft = ""
    @State private var selectedTab: TodoTab = .oneOff
    @State private var inputError: String?
    @FocusState private var inputIsFocused: Bool

    private var showingRecurring: Bool {
        selectedTab == .recurring
    }

    private var showingToday: Bool {
        selectedTab == .today
    }

    var body: some View {
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
                if !store.hasItems(
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
        .frame(minWidth: 440, idealWidth: 520, minHeight: 480, idealHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
            inputIsFocused = true
        }
        .onAppear {
            focusInput()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusTodoInput)) { _ in
            selectedTab = .oneOff
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

            Text("⌥N brings this window back anytime.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.tertiary)

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

        return HStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    store.complete(item)
                }
                focusInput()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(isOverdue ? .red : .secondary)

                    VStack(alignment: .leading, spacing: 4) {
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
                    }

                    Spacer(minLength: 0)
                }
                .padding(.leading, 28)
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete " + item.title)

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
                .padding(.trailing, 16)
                .accessibilityLabel("Delete " + item.title)
                .help("Delete recurring reminder")
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
                .padding(.trailing, 16)
                .accessibilityLabel("Move " + item.title + " to Today")
                .help("Move to Today")
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
                .padding(.trailing, 16)
                .accessibilityLabel("Move " + item.title + " back to One-off")
                .help("Move back to One-off")
            }
        }
    }

    private var inputPlaceholder: String {
        switch selectedTab {
        case .oneOff:
            "What needs doing?"
        case .today:
            "What are you working on today?"
        case .recurring:
            "Pay rent on the first of every month at 9 am"
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
        }
    }

    private func addTask() {
        let title = draft
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            draft = ""
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
}
