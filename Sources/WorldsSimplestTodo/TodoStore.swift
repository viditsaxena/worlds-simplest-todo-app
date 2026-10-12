import Foundation
#if os(macOS)
import AppKit
#endif

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []
    @Published private(set) var birthdays: [BirthdayItem] = []

    private let defaults: UserDefaults
    private let storageKey = "todo-items"
    private let birthdayStorageKey = "birthdays"
    private let snapshotKey = "shared-data-v1"
    private let cloudStore: NSUbiquitousKeyValueStore
    private let reminders: any ReminderScheduling
    private var observers: [NSObjectProtocol] = []
    private var attentionTasks: [UUID: Task<Void, Never>] = [:]
    private var snapshotUpdatedAt = Date.distantPast

    private struct DataSnapshot: Codable {
        let items: [TodoItem]
        let birthdays: [BirthdayItem]
        let updatedAt: Date
    }

    init(
        defaults: UserDefaults = .standard,
        cloudStore: NSUbiquitousKeyValueStore = .default,
        reminders: any ReminderScheduling = ReminderScheduler()
    ) {
        self.defaults = defaults
        self.cloudStore = cloudStore
        self.reminders = reminders
        load()
        observeNotificationActions()
        observeCloudChanges()
        cloudStore.synchronize()
        applyCloudSnapshotIfNewer()
        rescheduleAllReminders()
    }

    @discardableResult
    func add(
        _ rawTitle: String,
        requiresRecurrence: Bool = false,
        isToday: Bool = false
    ) -> TodoItem? {
        let parsed = ReminderParser.parse(rawTitle)
        guard !parsed.title.isEmpty,
              !requiresRecurrence || parsed.recurrence != nil else {
            return nil
        }

        let item = TodoItem(
            title: parsed.title,
            reminderDate: parsed.reminderDate,
            recurrence: parsed.recurrence,
            isToday: isToday && parsed.recurrence == nil
        )
        items.append(item)
        save()

        Task {
            await reminders.schedule(for: item)
        }
        scheduleDockBounce(for: item)
        return item
    }

    func complete(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        attentionTasks[item.id]?.cancel()
        attentionTasks[item.id] = nil

        if let recurrence = item.recurrence {
            let nextDate = recurrence.nextDate(after: Date())
            let advanced = TodoItem(
                id: item.id,
                title: item.title,
                createdAt: item.createdAt,
                reminderDate: nextDate,
                recurrence: recurrence,
                hiddenUntil: nil,
                isToday: false
            )
            items[index] = advanced
            save()
            Task {
                await reminders.cancel(for: item)
                await reminders.schedule(for: advanced)
            }
            scheduleDockBounce(for: advanced)
        } else {
            items.remove(at: index)
            save()
            Task {
                await reminders.cancel(for: item)
            }
        }
    }

    func delete(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        attentionTasks[item.id]?.cancel()
        attentionTasks[item.id] = nil
        items.remove(at: index)
        save()

        Task {
            await reminders.cancel(for: item)
        }
    }

    @discardableResult
    func addBirthday(_ rawInput: String) -> BirthdayItem? {
        guard let parsed = BirthdayParser.parse(rawInput) else { return nil }

        let birthday = BirthdayItem(
            name: parsed.name,
            month: parsed.month,
            day: parsed.day,
            reminderHour: parsed.hour,
            reminderMinute: parsed.minute
        )
        birthdays.append(birthday)
        save()
        Task {
            await reminders.schedule(for: birthday)
        }
        return birthday
    }

    func delete(_ birthday: BirthdayItem) {
        guard let index = birthdays.firstIndex(where: { $0.id == birthday.id }) else {
            return
        }
        birthdays.remove(at: index)
        save()
        Task {
            await reminders.cancel(for: birthday)
        }
    }

    func sortedBirthdays(after date: Date = Date()) -> [BirthdayItem] {
        birthdays.sorted { first, second in
            let firstDate = first.nextDate(after: date)
            let secondDate = second.nextDate(after: date)
            if firstDate != secondDate {
                return firstDate < secondDate
            }
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
    }

    func moveToToday(_ item: TodoItem) {
        setToday(true, for: item)
    }

    func moveToOneOff(_ item: TodoItem) {
        setToday(false, for: item)
    }

    func sortedItems(at date: Date, recurring: Bool, today: Bool = false) -> [TodoItem] {
        items.filter {
            let isInSelectedList = recurring
                ? $0.isRecurring
                : !$0.isRecurring && $0.isToday == today
            return isInSelectedList && $0.isVisible(at: date)
        }.sorted { first, second in
            let firstIsOverdue = first.isOverdue(at: date)
            let secondIsOverdue = second.isOverdue(at: date)

            if firstIsOverdue != secondIsOverdue {
                return firstIsOverdue
            }
            return first.createdAt > second.createdAt
        }
    }

    func hasItems(recurring: Bool, today: Bool = false, at date: Date) -> Bool {
        items.contains {
            let isInSelectedList = recurring
                ? $0.isRecurring
                : !$0.isRecurring && $0.isToday == today
            return isInSelectedList && $0.isVisible(at: date)
        }
    }

    private func setToday(_ isToday: Bool, for item: TodoItem) {
        guard !item.isRecurring,
              let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[index] = TodoItem(
            id: item.id,
            title: item.title,
            createdAt: item.createdAt,
            reminderDate: item.reminderDate,
            recurrence: item.recurrence,
            hiddenUntil: item.hiddenUntil,
            isToday: isToday
        )
        save()
    }

    private func load() {
        if let data = defaults.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode(DataSnapshot.self, from: data) {
            items = snapshot.items
            birthdays = snapshot.birthdays
            snapshotUpdatedAt = snapshot.updatedAt
            return
        }

        if let data = defaults.data(forKey: storageKey),
           let savedItems = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = savedItems
        }
        if let data = defaults.data(forKey: birthdayStorageKey),
           let savedBirthdays = try? JSONDecoder().decode([BirthdayItem].self, from: data) {
            birthdays = savedBirthdays
        }

        if !items.isEmpty || !birthdays.isEmpty {
            save()
        }
    }

    private func save() {
        let snapshot = DataSnapshot(
            items: items,
            birthdays: birthdays,
            updatedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        snapshotUpdatedAt = snapshot.updatedAt
        defaults.set(data, forKey: snapshotKey)
        defaults.set(try? JSONEncoder().encode(items), forKey: storageKey)
        defaults.set(try? JSONEncoder().encode(birthdays), forKey: birthdayStorageKey)
        cloudStore.set(data, forKey: snapshotKey)
        cloudStore.synchronize()
    }

    private func observeNotificationActions() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .completeTodoFromNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let id = notification.object as? UUID else { return }
                Task { @MainActor in
                    self?.complete(id: id)
                }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .snoozeTodoFromNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let id = notification.object as? UUID else { return }
                Task { @MainActor in
                    self?.snooze(id: id)
                }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .snoozeBirthdayFromNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let id = notification.object as? UUID else { return }
                Task { @MainActor in
                    self?.snoozeBirthday(id: id)
                }
            }
        )
    }

    private func observeCloudChanges() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: cloudStore,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.applyCloudSnapshotIfNewer()
                }
            }
        )
    }

    private func applyCloudSnapshotIfNewer() {
        guard let data = cloudStore.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(DataSnapshot.self, from: data),
              snapshot.updatedAt > snapshotUpdatedAt else {
            return
        }

        let previousItems = items
        let previousBirthdays = birthdays
        items = snapshot.items
        birthdays = snapshot.birthdays
        snapshotUpdatedAt = snapshot.updatedAt
        defaults.set(data, forKey: snapshotKey)
        defaults.set(try? JSONEncoder().encode(items), forKey: storageKey)
        defaults.set(try? JSONEncoder().encode(birthdays), forKey: birthdayStorageKey)

        attentionTasks.values.forEach { $0.cancel() }
        attentionTasks.removeAll()
        Task {
            for item in previousItems {
                await reminders.cancel(for: item)
            }
            for birthday in previousBirthdays {
                await reminders.cancel(for: birthday)
            }
            await rescheduleAllRemindersFromTask()
        }
    }

    private func rescheduleAllReminders() {
        items.forEach { scheduleDockBounce(for: $0) }
        Task {
            await rescheduleAllRemindersFromTask()
        }
    }

    private func rescheduleAllRemindersFromTask() async {
        for item in items {
            await reminders.cancel(for: item)
            await reminders.schedule(for: item)
        }
        for birthday in birthdays {
            await reminders.cancel(for: birthday)
            await reminders.schedule(for: birthday)
        }
    }

    private func complete(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        complete(item)
    }

    private func snooze(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        let current = items[index]
        let snoozed = TodoItem(
            id: current.id,
            title: current.title,
            createdAt: current.createdAt,
            reminderDate: Date().addingTimeInterval(10 * 60),
            recurrence: current.recurrence,
            hiddenUntil: nil,
            isToday: current.isToday
        )
        items[index] = snoozed
        save()

        Task {
            await reminders.cancel(for: current)
            await reminders.schedule(for: snoozed)
        }
        scheduleDockBounce(for: snoozed)
    }

    private func snoozeBirthday(id: UUID) {
        guard let birthday = birthdays.first(where: { $0.id == id }) else { return }
        Task {
            await reminders.snooze(
                birthday,
                until: Date().addingTimeInterval(10 * 60)
            )
        }
    }

    private func scheduleDockBounce(for item: TodoItem, after date: Date? = nil) {
#if os(macOS)
        attentionTasks[item.id]?.cancel()
        guard let reminderDate = item.reminderDate else { return }

        let followUpDate: Date
        if let date, let recurrence = item.recurrence {
            followUpDate = recurrence.nextDate(after: date).addingTimeInterval(10 * 60)
        } else {
            followUpDate = reminderDate.addingTimeInterval(10 * 60)
        }
        let delay = max(0, followUpDate.timeIntervalSinceNow)
        attentionTasks[item.id] = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard let self,
                  self.items.contains(where: { $0.id == item.id }) else {
                return
            }
            NSApp.requestUserAttention(.criticalRequest)
            self.attentionTasks[item.id] = nil

            if item.isRecurring {
                self.scheduleDockBounce(for: item, after: followUpDate)
            }
        }
#endif
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        attentionTasks.values.forEach { $0.cancel() }
    }
}
