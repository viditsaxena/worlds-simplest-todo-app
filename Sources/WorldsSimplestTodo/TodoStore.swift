import Foundation
import AppKit

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let defaults: UserDefaults
    private let storageKey = "todo-items"
    private let reminders = ReminderScheduler()
    private var observers: [NSObjectProtocol] = []
    private var attentionTasks: [UUID: Task<Void, Never>] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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

    func add(_ rawTitle: String) {
        let parsed = ReminderParser.parse(rawTitle)
        guard !parsed.title.isEmpty else { return }

        let item = TodoItem(
            title: parsed.title,
            reminderDate: parsed.reminderDate
        )
        items.append(item)
        save()

        Task {
            await reminders.schedule(for: item)
        }
        scheduleDockBounce(for: item)
    }

    func complete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()

        Task {
            await reminders.cancel(for: item)
        }
        attentionTasks[item.id]?.cancel()
        attentionTasks[item.id] = nil
    }

    func sortedItems(at date: Date) -> [TodoItem] {
        items.sorted { first, second in
            let firstIsOverdue = first.isOverdue(at: date)
            let secondIsOverdue = second.isOverdue(at: date)

            if firstIsOverdue != secondIsOverdue {
                return firstIsOverdue
            }
            return first.createdAt < second.createdAt
        }
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
            reminderDate: Date().addingTimeInterval(10 * 60)
        )
        items[index] = snoozed
        save()

        Task {
            await reminders.cancel(for: current)
            await reminders.schedule(for: snoozed)
        }
        scheduleDockBounce(for: snoozed)
    }

    private func scheduleDockBounce(for item: TodoItem) {
        attentionTasks[item.id]?.cancel()
        guard let reminderDate = item.reminderDate else { return }

        let followUpDate = reminderDate.addingTimeInterval(10 * 60)
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
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        attentionTasks.values.forEach { $0.cancel() }
    }
}
