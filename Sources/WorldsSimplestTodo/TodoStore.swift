import Foundation
import AppKit

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let defaults: UserDefaults
    private let storageKey = "todo-items"
    private let reminders: any ReminderScheduling
    private var observers: [NSObjectProtocol] = []
    private var attentionTasks: [UUID: Task<Void, Never>] = [:]

    init(
        defaults: UserDefaults = .standard,
        reminders: any ReminderScheduling = ReminderScheduler()
    ) {
        self.defaults = defaults
        self.reminders = reminders
        load()
        observeNotificationActions()
        items.forEach { item in
            scheduleDockBounce(for: item)
            Task {
                await reminders.cancel(for: item)
                await reminders.schedule(for: item)
            }
        }
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
        guard let data = defaults.data(forKey: storageKey),
              let savedItems = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return
        }

        items = savedItems
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
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

    private func scheduleDockBounce(for item: TodoItem, after date: Date? = nil) {
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
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        attentionTasks.values.forEach { $0.cancel() }
    }
}
