# hyprclip

A small floating clipboard history panel for [Hyprland](https://hyprland.org), built with [Quickshell](https://quickshell.org) on top of [cliphist](https://github.com/sentriz/cliphist).

Press a key and a compact card pops up where the mouse is, like the Windows clipboard panel. Click an entry to copy it, press `Del` to forget it.

![hyprclip screenshot](../assets/hyprclip.png)

## Features

- Compact card that opens at the cursor and flips to stay on screen, with a blurred backdrop
- Text entries with a three-line preview, image entries with a thumbnail
- Click or `Enter` copies the entry and closes the panel
- `Del` or the × button removes an entry; "Clear all" wipes the history (asks first)
- Keyboard navigation with arrows, `PageUp`/`PageDown`, `Home`/`End`
- Runs as a daemon and opens instantly through Quickshell IPC
- UI in English, or Brazilian Portuguese when `LANG` starts with `pt`

## Requirements

- Hyprland (tested on 0.56)
- Quickshell 0.3 or newer
- Qt 6 with QtQuick
- `cliphist`, `wl-clipboard` (`wl-copy` / `wl-paste`)

`cliphist` has to be collecting your clipboard already, the usual way:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
```

## Install

```sh
git clone https://github.com/bayonemt/hyprkit ~/.config/quickshell/hyprkit
```

Then wire it into Hyprland. With the Lua config (`hyprland.lua`):

```lua
-- start the daemon with the session
hl.on("hyprland.start", function()
  hl.exec_cmd("~/.config/quickshell/hyprkit/hyprclip/scripts/toggle.sh --daemon")
end)

-- toggle with Super+V
hl.bind("SUPER + V", hl.dsp.exec_cmd("~/.config/quickshell/hyprkit/hyprclip/scripts/toggle.sh"))

-- blur the card
hl.layer_rule({
  name = "hyprclip",
  match = { namespace = "^(hyprclip)$" },
  blur = true,
  ignore_alpha = 0.2,
})
```

With the classic `hyprland.conf`:

```ini
exec-once = ~/.config/quickshell/hyprkit/hyprclip/scripts/toggle.sh --daemon
bind = SUPER, V, exec, ~/.config/quickshell/hyprkit/hyprclip/scripts/toggle.sh
layerrule = blur, hyprclip
layerrule = ignorealpha 0.2, hyprclip
```

## Usage

| Key | Action |
| --- | --- |
| `↑` `↓` / `PageUp` `PageDown` / `Home` `End` | move selection |
| `Enter` / click | copy and close |
| `Del` / × | delete entry |
| `Esc` / click outside | close |

## IPC

```sh
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprclip/Main.qml call hyprclip toggle
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprclip/Main.qml call hyprclip open
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprclip/Main.qml call hyprclip close
```

## Tweaking

Everything lives in `ClipPanel.qml`: card size, colors, radius and the preview line count are properties near the top. Set `HYPRCLIP_DB` to point cliphist at another database (useful for demos). Image thumbnails are cached in `~/.cache/hyprclip`.

After editing, restart the daemon:

```sh
pkill -f hyprclip/Main.qml && ~/.config/quickshell/hyprkit/hyprclip/scripts/toggle.sh --daemon
```

## License

MIT, see [LICENSE](../LICENSE). Part of [hyprkit](../README.md).
