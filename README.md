# cct — Claude Code sessions in the menu bar

A SwiftBar plugin that lists your running Claude Code sessions in Ghostty.
Click a session to jump to its tab. The icon pulses when a session needs you.

## Prerequisites

- macOS
- [Ghostty](https://ghostty.org) 1.3.0 or later (needs its AppleScript support)
- [SwiftBar](https://github.com/swiftbar/SwiftBar): `brew install --cask swiftbar`
- [jq](https://jqlang.org): `brew install jq`
- Claude Code with hooks support

## Install

1. Launch SwiftBar once and choose a plugin folder.
2. Run `./install.sh`.
3. The first time you click a session, macOS asks whether SwiftBar may control Ghostty. Allow it.
   You can change this later in System Settings → Privacy & Security → Automation.

`install.sh` adds hooks to `~/.claude/settings.json` (it makes a backup first) and symlinks the plugin into SwiftBar's folder.
Running it again is safe. To remove everything, run `./install.sh --uninstall`.

Sessions that were already running show up after their next prompt.

## Menu bar icon

| Icon | Meaning |
|---|---|
| Orange ❗ + count | A session is waiting for you (permission prompt or question) |
| Green ✓ + count | A session finished and you haven't looked at it yet |
| Plain bubbles | Nothing needs you |

The icon is a status indicator. It never blinks or animates.

A finished session counts as seen once you focus its tab, through the menu or by hand.

## Customizing

Create `~/.cct/config` and override any of these. Icons are [SF Symbol](https://developer.apple.com/sf-symbols/) names; browse them with `brew install --cask sf-symbols`.

```bash
ICON_IDLE=bubble.left.and.text.bubble.right
ICON_WAITING=exclamationmark.bubble.fill
ICON_DONE=checkmark.bubble.fill
COLOR_WAITING=#FF9500
COLOR_DONE=#34C759
COLOR_BUSY=#0A84FF
COLOR_IDLE=#8E8E93
```

Changes apply after `open -g swiftbar://refreshallplugins` or a SwiftBar restart.
Set `CCT_CONFIG` to use a different file.

## How it works

- **`bin/cct-hook`** runs on Claude Code hook events and writes one JSON file per session to `~/.cct/sessions/`.
  It records the cwd, the `claude` process pid and its TTY, and a status:
  `busy` → `waiting` (permission prompt) → `busy` → `done` (turn finished) → `idle` (seen).
- **`plugin/cct.sh`** is a streamable SwiftBar plugin. It redraws the menu from the state files and removes sessions whose process has died.
- **`bin/cct-focus`** finds the session's Ghostty tab and focuses it.
  Ghostty's AppleScript doesn't expose a terminal's TTY, so it writes a unique title to the TTY and asks Ghostty which terminal has that title.
  It caches the terminal id for later clicks.

Set `CCT_STATE_DIR` to use a different state directory.
Hook errors go to `hook.log` in the state directory's parent (default `~/.cct/hook.log`).

## Limitations

- Ghostty only.
- Focusing a busy session can take a few tries internally, because Claude's spinner keeps rewriting the tab title.
