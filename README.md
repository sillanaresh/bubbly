# Habibi Float

Habibi Float is a tiny native macOS companion app. It shows a custom 2D jelly-bubble pet that floats above the desktop, wanders gently, reacts to clicks, and stays controllable from the menu bar.

## Local Development

Run tests:

```sh
swift test
```

Build the release executable:

```sh
swift build -c release
```

Build a local `.app` bundle:

```sh
./scripts/build-app.sh
```

Launch it:

```sh
open "dist/Habibi Float.app"
```

## Controls

- Drag the bubble to move it.
- Click the bubble for a happy bounce.
- Double-click the bubble to pause or resume wandering.
- Right-click the bubble for controls.
- Use the menu bar icon to show, hide, pause, reset, change sounds, open About, or quit.
- Use `Click Sound` to choose between Water Drop, Soft Bloop, Jelly Pop, Budak, Bubble Chime, or No Sound.
- Use `Sound Volume` to choose Soft, Normal, or Loud.

## Distribution

DMG packaging is intentionally not included yet. The current milestone is to build and polish the local app first. Once the app behavior and look are locked, the next step is to add a DMG packaging script.

## Friend Notes

Habibi Float is a local-only Mac app:

- It does not use the internet.
- It does not track anything.
- It does not collect analytics.
- It saves only local preferences like position, pause state, and selected sound.

To close it, use the menu bar icon and choose `Quit Habibi Float`.

When shared as an unsigned app, macOS may show a security warning. Friends may need to right-click the app and choose `Open`. Developer ID signing and notarization can be added later for smoother public distribution.
