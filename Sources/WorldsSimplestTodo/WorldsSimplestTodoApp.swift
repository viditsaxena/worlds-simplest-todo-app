import SwiftUI

@main
struct WorldsSimplestTodoApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#elseif os(iOS)
    @UIApplicationDelegateAdaptor(MobileAppDelegate.self) private var appDelegate
#endif
    @StateObject private var store = TodoStore()

    var body: some Scene {
#if os(macOS)
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
#else
        WindowGroup {
            TodoView(store: store)
        }
#endif
    }
}
