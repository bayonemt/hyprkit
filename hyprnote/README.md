# hyprnote

A notebook that lives on top of your desktop. Built for [Hyprland](https://hyprland.org) with [Quickshell](https://quickshell.org).

Press a key, the desktop blurs, and an open book appears. Write, save, close. Every page is a plain Markdown file, so `grep`, `git` and your editor work on your notes too.

![hyprnote screenshot](../assets/hyprnote.png)

## Features

- Full-screen overlay on the focused monitor, with the blur done by Hyprland itself
- Two ruled pages side by side, serif font, page numbers
- One `.md` file per page, in a folder you choose
- Save with a button or `Ctrl+S`; pages are also saved when you turn them and when you close the overlay
- Unsaved pages show a dot next to the page number
- New pages with a button, `Ctrl+N`, or by clicking the empty right-hand page
- Runs as a daemon and opens instantly through Quickshell IPC
- UI in English, or Brazilian Portuguese when `LANG` starts with `pt`

## Requirements

- Hyprland (tested on 0.56)
- Quickshell 0.3 or newer
- Qt 6 with QtQuick
- A serif font. It looks for `Noto Serif` and falls back to whatever fontconfig gives.

## Install

```sh
git clone https://github.com/bayonemt/hyprkit ~/.config/quickshell/hyprkit
```

Then wire it into Hyprland. With the Lua config (`hyprland.lua`):

```lua
-- start the daemon with the session
hl.on("hyprland.start", function()
  hl.exec_cmd("~/.config/quickshell/hyprkit/hyprnote/scripts/toggle.sh --daemon")
end)

-- toggle with Super+N
hl.bind("SUPER + N", hl.dsp.exec_cmd("~/.config/quickshell/hyprkit/hyprnote/scripts/toggle.sh"))

-- blur the backdrop
hl.layer_rule({
  name = "hyprnote",
  match = { namespace = "^(hyprnote)$" },
  blur = true,
  ignore_alpha = 0.2,
})
```

With the classic `hyprland.conf`:

```ini
exec-once = ~/.config/quickshell/hyprkit/hyprnote/scripts/toggle.sh --daemon
bind = SUPER, N, exec, ~/.config/quickshell/hyprkit/hyprnote/scripts/toggle.sh
layerrule = blur, hyprnote
layerrule = ignorealpha 0.2, hyprnote
```

Blur has to be enabled in `decoration:blur` for the backdrop effect to show.

## Where the notes go

By default pages are stored in `~/Documents/hyprnote` as `page-001.md`, `page-002.md`, and so on. Set `HYPRNOTE_DIR` to change that. It has to be set for the daemon, so put it in front of both commands:

```lua
hl.exec_cmd("HYPRNOTE_DIR=$HOME/notes ~/.config/quickshell/hyprkit/hyprnote/scripts/toggle.sh --daemon")
hl.bind("SUPER + N", hl.dsp.exec_cmd("HYPRNOTE_DIR=$HOME/notes ~/.config/quickshell/hyprkit/hyprnote/scripts/toggle.sh"))
```

The folder is created on first run. Files are read when the overlay opens, so edits made outside show up the next time you open it.

## Usage

| Key | Action |
| --- | --- |
| `Ctrl+S` | save |
| `Ctrl+N` | new page |
| `PageUp` / `PageDown` (or `Ctrl+←` / `Ctrl+→`) | turn the page |
| `Esc` / click outside | close (and save) |

## IPC

The daemon exposes a Quickshell IPC target called `hyprnote`:

```sh
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprnote/Main.qml call hyprnote toggle
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprnote/Main.qml call hyprnote open
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprnote/Main.qml call hyprnote close
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprnote/Main.qml call hyprnote newPage
quickshell ipc -p ~/.config/quickshell/hyprkit/hyprnote/Main.qml call hyprnote save
```

`scripts/toggle.sh` wraps this: it starts the daemon if needed and then toggles. `toggle.sh --daemon` only starts it, which is what you want on `exec-once`.

## Tweaking

Everything lives in `Notebook.qml`. Paper and ink colors, the book size and the font are properties at the top of the file. Sizes scale with the monitor width (1920 px is the base).

After editing, restart the daemon:

```sh
pkill -f hyprnote/Main.qml && ~/.config/quickshell/hyprkit/hyprnote/scripts/toggle.sh --daemon
```

## License

MIT, see [LICENSE](../LICENSE). Part of [hyprkit](../README.md).
