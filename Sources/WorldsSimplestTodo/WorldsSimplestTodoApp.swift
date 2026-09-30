import SwiftUI

@main
struct WorldsSimplestTodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TodoStore()

    var body: some Scene {
        WindowGroup("World's Simplest To-Do") {
            TodoView(store: store)
        }
        .defaultSize(width: 520, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Toggle To-Do") {
                    NotificationCenter.default.post(name: .toggleTodoWindow, object: nil)
                }
            }
        }
    }
}
