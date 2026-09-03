# hyprws

A workspace overview with drag-and-drop for [Hyprland](https://hyprland.org), built with [Quickshell](https://quickshell.org).

Press a key and every monitor shows its workspaces as miniatures, with the windows drawn where they really are and updating live. Drag a window onto another card to move it there, even a card on another monitor. Click a card to switch, click a window to focus it.

![hyprws screenshot](../assets/hyprws.png)

## Features

- Opens on every monitor at once; each one shows its own workspaces as cards in the monitor's aspect ratio, plus a "New" card that creates the next workspace
- Multi-monitor drag-and-drop: start dragging on one screen, move the mouse to the other, drop on a card there. The window moves to that monitor's workspace
- Windows drawn at their real position and size, with live thumbnails (falls back to app icon and title when a window cannot be captured)
- Drag a window between cards to move it; the target card lights up, the window stays where it is until you drop
- Click a card to switch, click a window to focus it, middle-click a window to close it
- `1`–`9` switch workspaces, `←` `→` + `Enter` select a card, `Esc` closes
- Refreshes itself on Hyprland events while open (windows opening, closing, moving)
- Runs as a daemon and opens instantly through Quickshell IPC
- UI in English, or Brazilian Portuguese when `LANG` starts with `pt`

## Requirements

- Hyprland 0.55 or newer (the moves are issued through the Lua dispatcher API)
- Quickshell 0.3 or newer, Qt 6 with QtQuick
- Live thumbnails need Hyprland's toplevel capture, which Quickshell uses through `ScreencopyView`; without it you get icons instead

## Install

```sh
git clone https://github.com/bayonemt/hyprkit ~/.config/quickshell/hyprkit
```

Then wire it into Hyprland. With the Lua config (`hyprland.lua`):

```lua
-- start the daemon with the session
hl.on("hyprland.start", function()
  hl.exec_cmd("~/.config/quickshell/hyprkit/hyprws/scripts/toggle.sh --daemon")
end)

-- toggle with Super+Tab
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("~/.config/quickshell/hyprkit/hyprws/scripts/toggle.sh"))

-- blur the backdrop
hl.layer_rule({
  name = "hyprws",
  match = { namespace = "^(hyprws)$" },
  blur = true,
  ignore_alpha = 0.2,
})
```

With the classic `hyprland.conf`:

```ini
exec-once = ~/.config/quickshell/hyprkit/hyprws/scripts/toggle.sh --daemon
bind = SUPER, TAB, exec, ~/.config/quickshell/hyprkit/hyprws/scripts/toggle.sh
layerrule = blur, hyprws
layerrule = ignorealpha 0.2, hyprws
```

## Usage

| Action | Result |
| --- | --- |
| click a card | switch to that workspace |
| click the "New" card | create and switch to the next workspace |
| click a window | focus it (switching workspace if needed) |
| drag a window onto another card | move it there, without switching |
| drag a window onto a card on another monitor | move it to that monitor's workspace |
| middle-click a window | close it |
| `1`–`9` | switch to that workspace |
| `←` `→` then `Enter` | select and switch |
| `Esc` / click outside | close |

## IPC

```sh
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprws/Main.qml call hyprws toggle
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprws/Main.qml call hyprws open
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprws/Main.qml call hyprws close
```

## How it works

State comes from `hyprctl -j monitors`, `workspaces` and `clients`, re-read whenever Hyprland emits an event while the overview is open. Actions go through `hyprctl eval` with the Lua dispatchers (`hl.dsp.focus`, `hl.dsp.window.move`, `hl.dsp.window.close`), so they work with the Lua config format introduced in Hyprland 0.55. Drag-and-drop is done by hand: a ghost follows the pointer and the drop target is hit-tested on release, which keeps the window items inside their (clipped) cards. There is one overlay per monitor, and they share a single drag state in global coordinates. While the button is held the compositor keeps sending pointer motion to the overlay where the drag started, so that overlay publishes the global pointer position and the overlay under the pointer draws the ghost and highlights its card. Dropping on another monitor's "New" card moves the window to the fresh workspace and then moves that workspace to the right monitor.

## Tweaking

Card sizes (`maxCardW`, `minCardW`), colors and the backdrop opacity are properties near the top of `Overview.qml`. Sizes scale with the monitor width (1920 px is the base).

After editing, restart the daemon:

```sh
pkill -f hyprws/Main.qml && ~/.config/quickshell/hyprkit/hyprws/scripts/toggle.sh --daemon
```

## License

MIT, see [LICENSE](../LICENSE). Part of [hyprkit](../README.md).
