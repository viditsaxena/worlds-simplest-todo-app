# World's Simplest To-Do

A deliberately tiny macOS to-do app.

- Press **⌥N** from anywhere to bring it forward.
- Start typing immediately—no click required.
- Press **Return** to add an item.
- Click an item's circle to complete and remove it.
- Unfinished items are saved automatically.

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
