# cct — Claude Code sessions in the menu bar

Running many Claude Code sessions as Ghostty tabs makes it hard to tell which one needs you.
cct puts a small icon in the macOS menu bar that keeps track for you.

- The number next to the icon counts sessions that need you.
- The dropdown lists every session with its status, project and last prompt.
- Click a session to jump to its Ghostty tab.

The icon is a status indicator. It never blinks or animates.

## Contents

- [Requirements](#requirements)
- [Installing the prerequisites](#installing-the-prerequisites)
- [Install cct](#install-cct)
- [Using it](#using-it)
- [Customizing](#customizing)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)
- [How it works](#how-it-works)
- [Limitations](#limitations)

## Requirements

| Requirement | Version | Why |
|---|---|---|
| macOS | 12 Monterey or later | SwiftBar's minimum |
| [Homebrew](https://brew.sh) | any | Easiest way to install the rest |
| [Ghostty](https://ghostty.org) | 1.3.0 or later | Its AppleScript support is used to find and focus tabs |
| [SwiftBar](https://github.com/swiftbar/SwiftBar) | 2.x | Runs the menu bar plugin |
| [jq](https://jqlang.org) | 1.6 or later | Reads and writes the session state files |
| [Claude Code](https://code.claude.com) | a recent version with hooks | Reports session state through hooks |

No other tools are needed. The scripts run on the bash that ships with macOS.

Tested with macOS 26.3, Ghostty 1.3.1, SwiftBar 2.1.1, jq 1.8.1 and Claude Code 2.1.293.

## Installing the prerequisites

### Homebrew

Check if you have it:

```bash
brew --version
```

If not, install it with the command from [brew.sh](https://brew.sh):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Ghostty

```bash
brew install --cask ghostty
```

Already installed? Check the version. It must be 1.3.0 or later:

```bash
ghostty +version
```

Ghostty updates itself. You can also update it from the menu: **Ghostty → Check for Updates…**.

AppleScript must be enabled in Ghostty. It is by default.
If your Ghostty config has `macos-applescript = false`, remove that line and restart Ghostty.

### SwiftBar

```bash
brew install --cask swiftbar
```

Then set it up:

1. Open SwiftBar from Applications.
2. It asks you to choose a **plugin folder**. Pick or create any empty folder, e.g. `~/Documents/swiftbar`.
3. Optional: in SwiftBar's preferences, turn on **Launch at Login** so cct is always there.

You can check which folder SwiftBar uses:

```bash
defaults read com.ameba.SwiftBar PluginDirectory
```

### jq

```bash
brew install jq
jq --version
```

### Claude Code

See the [Claude Code docs](https://code.claude.com) to install it. Check your version with:

```bash
claude --version
```

## Install cct

```bash
git clone git@github.com:kallestorytel/cct.git ~/code/cct
cd ~/code/cct
./install.sh
```

`install.sh` does three things:

1. Checks that Ghostty (1.3.0+), SwiftBar and jq are installed, and stops with a clear message if one is missing.
2. Symlinks `plugin/cct.sh` into SwiftBar's plugin folder.
3. Adds cct's hooks to `~/.claude/settings.json`. It saves a backup to `~/.claude/settings.json.cct-backup` first.
   Your other settings and hooks are left alone.

Running it again is safe. It replaces cct's hooks instead of adding duplicates.

Keep the repo where you cloned it. The symlink and the hooks point into it.

### After installing

- **Sessions that were already running** show up after their next prompt. New sessions show up right away.
- **macOS permission:** the first time cct talks to Ghostty, macOS asks whether **SwiftBar** may control **Ghostty**. Click **OK**.
  This usually happens the first time you click a session, or when a session finishes.
  If you clicked **Don't Allow**, see [Troubleshooting](#troubleshooting).
- **Hooks not firing?** Run `/hooks` in a Claude Code session to see whether cct's hooks are loaded. Restarting the session also reloads them.

## Using it

### Menu bar

| You see | Meaning |
|---|---|
| Icon only | Nothing needs you |
| Icon + number | That many sessions need you |

A session "needs you" when it is:

- **waiting**: blocked on you, e.g. a permission prompt or a question, or
- **done**: finished its turn and you haven't looked at it yet.

### Dropdown

Each session shows its project folder, status and how long it has been in that status. Its last prompt is shown underneath.

| Status | Color | Meaning |
|---|---|---|
| waiting | orange | Claude is blocked on you |
| done | green | Claude finished; you haven't looked yet |
| busy | blue | Claude is working |
| idle | grey | Nothing happening |

An idle or done session also shows **monitoring** when it still has background work running, such as a Monitor watch or a background command.

Sessions are sorted most urgent first.

### Seen

A finished session becomes idle as soon as you look at it, either by clicking it in the menu or by switching to its tab yourself.
"Looking" means its tab is focused and Ghostty is the frontmost app.

## Customizing

Create `~/.cct/config` and set any of these:

```bash
ICON=ipod.shuffle.gen1   # menu bar icon, an SF Symbol name
COLOR_WAITING=#FF9500    # dropdown colors, as hex
COLOR_DONE=#34C759
COLOR_BUSY=#0A84FF
COLOR_IDLE=#8E8E93
```

To browse SF Symbol names, install Apple's SF Symbols app:

```bash
brew install --cask sf-symbols
```

Right-click a symbol and choose **Copy Name**.

The colors apply to the dropdown only. The menu bar icon always follows the system's menu bar color.

Apply changes by reloading SwiftBar:

```bash
open -g swiftbar://refreshallplugins
```

### Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `CCT_CONFIG` | `~/.cct/config` | Config file location |
| `CCT_STATE_DIR` | `~/.cct/sessions` | Where session state is stored |

## Uninstall

```bash
cd ~/code/cct
./install.sh --uninstall
```

This removes cct's hooks from `~/.claude/settings.json` and the plugin symlink from SwiftBar's folder.
It saves a settings backup to `~/.claude/settings.json.cct-backup` first.

To also remove state, config and logs:

```bash
rm -rf ~/.cct
```

## Troubleshooting

**A session doesn't show up.**
It shows up after its next prompt. If it still doesn't, check `~/.cct/hook.log` for errors.
Also check that the hooks are installed:

```bash
jq '.hooks | keys' ~/.claude/settings.json
```

You should see `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `Notification`, `Stop` and `SessionEnd`.

**Clicking a session does nothing.**
SwiftBar probably isn't allowed to control Ghostty.
Open **System Settings → Privacy & Security → Automation**, find **SwiftBar**, and turn on **Ghostty**.
If SwiftBar isn't listed, reset the permission and click a session again:

```bash
tccutil reset AppleEvents com.ameba.SwiftBar
```

**The icon doesn't appear.**
Check that the plugin is linked into SwiftBar's folder:

```bash
ls -l "$(defaults read com.ameba.SwiftBar PluginDirectory)"
```

If `cct.sh` is missing, run `./install.sh` again.
Also check that the plugin isn't disabled: open SwiftBar's preferences and look at the plugin list.

**A session's count never clears.**
Make sure Ghostty is the frontmost app while that tab is focused, or click the session in the menu.

**`install.sh` says SwiftBar has no plugin folder.**
Open SwiftBar once and choose a folder, then run `./install.sh` again.

**Seeing what the plugin outputs.**
Run it directly in a terminal. Stop it with Ctrl+C:

```bash
./plugin/cct.sh
```

## How it works

cct has three parts.

**`bin/cct-hook`** runs on Claude Code hook events. It writes one JSON file per session to `~/.cct/sessions/`.
Each file holds the session's folder, the pid and TTY of its `claude` process, its last prompt and its status:

| Hook event | Status becomes |
|---|---|
| `SessionStart` | idle |
| `UserPromptSubmit` | busy |
| `PostToolUse` | busy |
| `Notification` (permission prompt or question) | waiting |
| `Stop` | done |
| `SessionEnd` | file removed |

Hooks run without a terminal, so it finds the `claude` process by walking up its parent processes.
Errors go to `~/.cct/hook.log`, because Claude Code discards the output of background hooks.

**`plugin/cct.sh`** is a streamable SwiftBar plugin. It runs continuously and checks the state files about twice a second.
It only redraws the menu when something changes. It also:

- removes sessions whose `claude` process has exited, which covers crashes that skip `SessionEnd`,
- marks a done session as idle when its tab is focused,
- detects background work, shown as "monitoring".

The dropdown icons are inline `:symbol:` text colored with `sfcolor`. Colored `sfimage` icons get washed out by macOS's menu dimming, so cct doesn't use them.

**`bin/cct-focus`** and **`bin/cct-probe`** find and focus a session's Ghostty tab.
Ghostty's AppleScript doesn't expose a terminal's TTY. So cct-probe briefly sets a unique title on the session's TTY and asks Ghostty which terminal has that title.
The terminal id is cached for later.

## Limitations

- **Ghostty only.** Other terminals aren't supported.
- **"monitoring" is a heuristic.** Claude Code has no hook for background tasks. cct looks for shell processes that `claude` started, so a long background command shows up the same way as a Monitor watch.
- **Finding a busy session's tab can take a moment.** Claude's spinner keeps rewriting the tab title, so cct-probe may need a few tries.
- **Interrupted turns.** If you interrupt Claude with Esc, the `Stop` hook may not fire. The session then shows as busy until Claude Code's idle notification arrives.
