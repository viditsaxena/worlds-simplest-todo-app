import Foundation

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let defaults: UserDefaults
    private let storageKey = "todo-items"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ rawTitle: String) {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        items.append(TodoItem(title: title))
        save()
    }

    func complete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
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
}
