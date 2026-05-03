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

To configure sponsored chat in the app bundle, pass the deployed backend URL at build time:

```sh
HABIBI_CHAT_BACKEND_URL="https://your-worker.example/v1/chat" ./scripts/build-app.sh
```

Launch it:

```sh
open "dist/Habibi Float.app"
```

Build a shareable unsigned DMG:

```sh
./scripts/package-dmg.sh
```

## Controls

- Drag the bubble to move it.
- Click the bubble for a happy bounce.
- Double-click the bubble to pause or resume wandering.
- Right-click the bubble for controls.
- Click the small chat badge to pin the bubble and open chat.
- Use the menu bar icon to show, hide, pause, reset, change sounds, open About, or quit.
- Use `Theme` to change the pet colors.
- Use `Mood` to switch between Happy, Sleepy, Shy, and Focus.
- Use `Character` to switch between Bubble, Dot, Sprout, and Star.
- Use `Smart Positioning` to keep wandering biased away from common active app controls.
- Use `Click Sound` to choose between Water Drop, Soft Bloop, Jelly Pop, Budak, Bubble Chime, or No Sound.
- Use `Sound Volume` to choose Soft, Normal, or Loud.

## Distribution

DMG packaging creates `dist/Habibi Float.dmg`. It contains the app plus an `/Applications` shortcut.

## AI Chat

The chat badge opens a compact floating panel next to the pet. Closing the panel unpins the pet and restores the previous pause or running state.

Chat supports three modes:

- `Sponsored`: calls the configured Habibi backend at `POST /v1/chat`.
- `Your OpenRouter Key`: stores a user-provided OpenRouter key in macOS Keychain and calls OpenRouter directly.
- `Offline`: disables network chat.

The sponsored backend lives in `backend/`. It proxies OpenRouter, enforces daily per-device limits, has a global guard, and keeps the OpenRouter key in Cloudflare environment secrets.

## Friend Notes

Habibi Float keeps pet behavior local. Chat uses the network only when a message is sent:

- It does not track anything.
- It does not collect analytics.
- It saves local preferences like position, pause state, selected sound, anonymous chat device ID, and selected chat mode.
- User OpenRouter keys are stored in macOS Keychain, not UserDefaults.

To close it, use the menu bar icon and choose `Quit Habibi Float`.

When shared as an unsigned app, macOS may show a security warning. Friends may need to right-click the app and choose `Open`. Developer ID signing and notarization can be added later for smoother public distribution.
