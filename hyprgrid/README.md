# hyprgrid

A GNOME-style application grid for [Hyprland](https://hyprland.org), built with [Quickshell](https://quickshell.org).

Press a key, the desktop blurs, and your apps show up in a paginated grid with a search box. Press it again (or `Esc`) and it goes away.

![hyprgrid screenshot](../assets/hyprgrid.png)

## Features

- Full-screen overlay on the focused monitor, with the blur done by Hyprland itself
- Paginated 6×4 grid with page dots, mouse wheel and `PageUp`/`PageDown` to flip pages
- Search that ignores accents (`musica` finds `Música`) and matches name, generic name and comment
- Keyboard navigation: arrows, `Tab`, `Enter` to launch, `Esc` to close
- Icons from your icon theme, with a colored tile fallback for apps that have none
- Runs as a daemon and opens instantly through Quickshell IPC
- UI in English, or Brazilian Portuguese when `LANG` starts with `pt`

## Requirements

- Hyprland (tested on 0.56)
- Quickshell 0.3 or newer
- Qt 6 with QtQuick
- Optional: the Qt GTK platform theme plugin (`qt6-qpa-gtk` / `qt6-gtk-platformtheme`), so Qt picks the icon theme from your GTK settings. The toggle script sets `QT_QPA_PLATFORMTHEME=gtk3` for you.

## Install

```sh
git clone https://github.com/bayonemt/hyprkit ~/.config/quickshell/hyprkit
```

Then wire it into Hyprland. With the Lua config (`hyprland.lua`):

```lua
-- start the daemon with the session
hl.on("hyprland.start", function()
  hl.exec_cmd("~/.config/quickshell/hyprkit/hyprgrid/scripts/toggle.sh --daemon")
end)

-- toggle with Super+A
hl.bind("SUPER + A", hl.dsp.exec_cmd("~/.config/quickshell/hyprkit/hyprgrid/scripts/toggle.sh"))

-- blur the backdrop
hl.layer_rule({
  name = "hyprgrid",
  match = { namespace = "^(hyprgrid)$" },
  blur = true,
  ignore_alpha = 0.2,
})
```

With the classic `hyprland.conf`:

```ini
exec-once = ~/.config/quickshell/hyprkit/hyprgrid/scripts/toggle.sh --daemon
bind = SUPER, A, exec, ~/.config/quickshell/hyprkit/hyprgrid/scripts/toggle.sh
layerrule = blur, hyprgrid
layerrule = ignorealpha 0.2, hyprgrid
```

Blur has to be enabled in `decoration:blur` for the backdrop effect to show.

## Usage

| Key | Action |
| --- | --- |
| type | search |
| `←` `→` `↑` `↓` / `Tab` | move selection |
| `Enter` | launch selected app |
| `PageUp` / `PageDown` / wheel | previous / next page |
| `Esc` / click outside | close |

## IPC

The daemon exposes a Quickshell IPC target called `hyprgrid`:

```sh
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprgrid/Main.qml call hyprgrid toggle
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprgrid/Main.qml call hyprgrid open
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprgrid/Main.qml call hyprgrid close
```

`scripts/toggle.sh` wraps this: it starts the daemon if needed and then toggles. `toggle.sh --daemon` only starts it, which is what you want on `exec-once`.

## Tweaking

Everything lives in `AppGrid.qml`. The grid size (`cols`, `rows`), cell and icon sizes, colors and the backdrop opacity are properties at the top of the file. Sizes scale with the monitor width (1920 px is the base).

After editing, restart the daemon:

```sh
pkill -f hyprgrid/Main.qml && ~/.config/quickshell/hyprkit/hyprgrid/scripts/toggle.sh --daemon
```

## License

MIT, see [LICENSE](../LICENSE). Part of [hyprkit](../README.md).
