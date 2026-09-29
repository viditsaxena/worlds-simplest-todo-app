import AppKit
import Carbon
import UserNotifications

private let showTodoEvent = Notification.Name("ShowTodoWindow")

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: showTodoEvent, object: nil)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )

        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("TODO"), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}

private func fourCharacterCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: GlobalHotKey?
    private var observer: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        ReminderNotification.registerActions()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        hotKey = GlobalHotKey()
        observer = NotificationCenter.default.addObserver(
            forName: showTodoEvent,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                Self.showWindow()
            }
        }

        Self.showWindow()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        Self.showWindow()
        return true
    }

    private static func showWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
            NotificationCenter.default.post(name: .focusTodoInput, object: nil)
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let rawID = response.notification.request.content.userInfo[
            ReminderNotification.todoIDKey
        ] as? String,
              let id = UUID(uuidString: rawID) else {
            return
        }

        let name: Notification.Name?
        switch response.actionIdentifier {
        case ReminderNotification.doneAction:
            name = .completeTodoFromNotification
        case ReminderNotification.snoozeAction:
            name = .snoozeTodoFromNotification
        default:
            name = nil
        }

        if let name {
            await MainActor.run {
                NotificationCenter.default.post(name: name, object: id)
            }
        }
    }
}

extension Notification.Name {
    static let focusTodoInput = Notification.Name("FocusTodoInput")
}
