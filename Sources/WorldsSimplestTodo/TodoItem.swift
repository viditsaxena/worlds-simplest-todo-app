import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let createdAt: Date

    init(id: UUID = UUID(), title: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
