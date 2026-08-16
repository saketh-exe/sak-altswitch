
This repository is a fork of [alt-switcher](https://github.com/pablo-merino/altswitch)
by Pablo Merino, adapted for my personal setup.


# Alt-tab switcher

Windows-style `ALT`+`TAB` for [Omarchy](https://omarchy.org/). Cycles every
window on every workspace, ordered by most recently used.

Hold `ALT`, tap `TAB` to open the list, navigate, and release `ALT` to jump to the
highlighted window.

![Preview](./icon.png)

## Features

- **App & WebApp Icons**: Automatically resolves desktop and webapp icons (Chrome, Brave, Chromium, Firefox PWAs, etc.) alongside clean brand formatting.
- **Arrow & Vim Navigation**: Navigate smoothly through the list using arrow keys or Vim (`j`/`k`) keys while holding `ALT`.
- **Workspace Number Cycling**: Press `ALT` + `[1-9, 0]` to jump directly to or cycle through windows on a specific workspace.
- **Frozen MRU Snapshot**: The window list is frozen at the moment you initiate the switch, preventing order shifts mid-navigation.
- **Virtual Selection**: Window focus only applies once you release `ALT`.

## Behaviour

| Keys | Action |
| --- | --- |
| `ALT`+`TAB` | Open the switcher and select the previous window |
| `ALT`+`TAB` again (with `ALT` held) | Move one further down the list |
| `ALT`+`SHIFT`+`TAB` | Move back up the list |
| `ALT`+`Down` / `ALT`+`Right` / `ALT`+`j` | Move down to the next window |
| `ALT`+`Up` / `ALT`+`Left` / `ALT`+`k` | Move up to the previous window |
| `ALT`+`1` .. `9`, `ALT`+`0` | Jump to and cycle through windows on that specific workspace (`0` for 10) |
| Release `ALT` | Switch to the highlighted window |
| `ALT`+`ESCAPE` | Cancel without switching |

Two things make this behave like Windows rather than like Hyprland's
`cyclenext`:

- The window list is snapshotted when the switch starts and then frozen, so the
  order cannot shuffle underneath you while you tab through it.
- Selection is virtual. Focus moves once, when you release `ALT`. Focusing on
  every tap would drag you across workspaces on the way past.

Special and scratchpad workspaces are excluded. Every monitor is included.

## Requirements

- Omarchy Quattro, for the shell plugin system
- Hyprland 0.56 or newer, configured in Lua

No other dependencies, and nothing to install beyond this repository.

## Install

Add the plugin and enable it:

```bash
omarchy plugin add https://github.com/saketh-exe/sak-altswitch.git --enable
```

Then load the keybindings from `~/.config/hypr/bindings.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/sak.altswitch/altswitch.lua")
```

Apply it with `hyprctl reload`.

That line replaces Omarchy's four default `ALT`+`TAB` bindings (`cyclenext` and
`bring_to_top`, in both directions). It unbinds them itself, so no other edit is
needed.

## Remove

Delete the `dofile` line from `~/.config/hypr/bindings.lua`, then:

```bash
hyprctl reload
omarchy plugin remove sak.altswitch
```

Omarchy's default `ALT`+`TAB` bindings come back on the next reload.

## How it works

The plugin is two halves that talk over Omarchy's shell IPC.

`altswitch.lua` runs inside Hyprland and owns all state and all keys. It reads
the window list from `hl.get_windows()`, sorted by Hyprland's own
`focus_history_id`, and drives the panel with `omarchy-shell altswitch
show|select|hide`.

`AltSwitch.qml` runs inside `omarchy-shell` and draws the list with resolved
application/webapp icons and badges. It takes no keyboard focus, so it cannot
trap your keyboard, and it hides itself after ten seconds if an `ALT` release is
ever missed.

Two Hyprland details are worth knowing if you plan to modify this:

- Committing on `ALT` release cannot be a keybind. A release bind on a modifier
  only fires when that modifier is tapped alone; pressing `TAB` in between
  cancels it. The raw `input.keyboard.key` event stream is read instead.
- Focusing a window from inside a key callback updates Hyprland's active window
  but does not settle until the next input event, so the focus dispatch is sent
  through `hyprctl` from outside that callback.

## Known limitations

- Keys that the switcher does not bind still reach the window underneath while
  the list is open. Blocking them needs an exclusive keyboard grab, which risks
  trapping the keyboard if a switch is ever left open.
- Rows show the app icon, workspace, app class, and window title. Window thumbnails
  are not currently supported.

## License

[MIT](LICENSE)
