# World's Simplest To-Do

A deliberately tiny macOS to-do app.

- Press **⌥N** from anywhere to bring it forward; press it again while the app is frontmost to minimize it.
- Start typing immediately—no click required.
- Use the **One-off** and **Recurring** tabs to keep the two kinds of task separate. The app always opens on One-off.
- Press **Return** to add an item.
- Click an item's circle to complete and remove it.
- Unfinished items are saved automatically.
- Add a date and time in plain English—such as **Call Mum tomorrow at 6 pm**—to schedule a native macOS notification automatically.
- If the task is still unfinished ten minutes later, the app sends a second notification and bounces its Dock icon while running.
- Overdue tasks are pinned to the top in red.
- Reminder notifications include **Done** and **Snooze 10 min** actions.
- Create monthly reminders in plain English, such as **Pay rent on the first of every month at 9 am**. If no time is included, the app uses 9:00 AM.
- Completing a recurring item advances it to the next month instead of deleting it.

## Requirements

- macOS 14 or later (the local build targets the macOS version it is built on)
- Swift 6.2 or later (to build from source)

## Build

```sh
chmod +x build-app.sh
./build-app.sh
```

The app will be created at `dist/World's Simplest To-Do.app`.

Move it to `/Applications` if you want to use it like any other Mac app.
