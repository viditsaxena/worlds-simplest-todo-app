# World's Simplest To-Do

A deliberately tiny to-do app for Mac and iPhone.

- Press **⌥N** from anywhere to bring it forward; press it again while the app is frontmost to minimize it.
- Start typing immediately—no click required.
- Use the **Today**, **One-off**, **Recurring**, and **Birthdays** tabs to keep different kinds of reminder separate. The app always opens on Today.
- Move a one-off task into Today with the sun button. Move it back with the return arrow.
- Set Today and One-off tasks to **High**, **Medium**, or **Low** priority. Both lists sort in that order, while preserving newest-first order within each priority.
- Press **Return** to add an item.
- Click a one-off item's circle to complete and remove it.
- Completing a task triggers a short fireworks celebration.
- Unfinished items are saved automatically.
- Add a date and time in plain English—such as **Call Mum tomorrow at 6 pm**—to schedule a native notification automatically.
- If the task is still unfinished ten minutes later, the app sends a second notification and bounces its Dock icon while running.
- Overdue tasks stay red and move above other tasks with the same priority.
- Reminder notifications include **Done** and **Snooze 10 min** actions.
- Create monthly reminders in plain English, such as **Pay rent on the first of every month at 9 am**. If no time is included, the app uses 9:00 AM.
- Completing a recurring item keeps it visible in black and advances its reminder to the next occurrence.
- Use the trash button beside a recurring item to delete the reminder completely.
- Add a birthday in plain English, such as **Mum's birthday is March 12 at 9 am**. It stays in the Birthdays tab and reminds you every year.
- When both builds are signed with the iCloud capability, tasks and birthdays sync between Mac and iPhone.

## Requirements

- macOS 14 or later for the Mac app
- iOS 17 or later for the iPhone app
- Xcode for installing the iPhone app

## Build

```sh
chmod +x build-app.sh
./build-app.sh
```

The app will be created at `dist/World's Simplest To-Do.app`.

Move it to `/Applications` if you want to use it like any other Mac app.

## Put it on an iPhone

1. Install Xcode from the Mac App Store.
2. Open `WorldsSimplestTodo.xcodeproj`.
3. Select the **WorldsSimplestTodo** target, open **Signing & Capabilities**, and choose your Apple development team.
4. Connect the iPhone to the Mac and approve the trust prompt.
5. Select the iPhone as the run destination and press **Run**.
6. If the iPhone asks for Developer Mode, enable it and run the app again.

A free Personal Team can install the app for testing, but its provisioning profile expires after seven days. iCloud key-value sync requires the iCloud capability available through an Apple Developer Program team. Without that capability, the app still works and saves its list locally on each device.
