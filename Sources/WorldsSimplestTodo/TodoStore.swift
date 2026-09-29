import Foundation

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let defaults: UserDefaults
    private let storageKey = "todo-items"
    private let reminders = ReminderScheduler()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
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
    }

    func complete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()

        Task {
            await reminders.cancel(for: item)
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
}
