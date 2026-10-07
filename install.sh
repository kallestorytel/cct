#!/usr/bin/env bash
# Installs cct: Claude Code hooks + SwiftBar plugin symlink.
# Usage: ./install.sh [--uninstall]
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
HOOK="$REPO/bin/cct-hook"
SETTINGS="$HOME/.claude/settings.json"

fail() { echo "error: $*" >&2; exit 1; }

check_prerequisites() {
  command -v jq > /dev/null || fail "jq not found. Install with: brew install jq"
  [ -d /Applications/Ghostty.app ] || fail "Ghostty.app not found in /Applications"
  local version
  version="$(osascript -e 'version of application "Ghostty"')"
  [ "$(printf '%s\n1.3.0\n' "$version" | sort -V | head -1)" = "1.3.0" ] \
    || fail "Ghostty $version is too old. cct needs 1.3.0+ for AppleScript support"
  [ -d /Applications/SwiftBar.app ] || fail "SwiftBar not found. Install with: brew install --cask swiftbar"
}

swiftbar_plugin_dir() {
  local dir
  dir="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null)" \
    || fail "SwiftBar has no plugin folder yet. Launch SwiftBar once and pick one, then re-run"
  echo "${dir/#\~/$HOME}"
}

# Removes every hook entry that runs cct-hook, then adds ours unless uninstalling.
write_hooks() {
  local mode=$1 current='{}'
  [ -f "$SETTINGS" ] && current="$(cat "$SETTINGS")" && cp "$SETTINGS" "$SETTINGS.cct-backup"
  jq --arg hook "$HOOK" --arg mode "$mode" '
    def entry($arg; $async): {hooks: [{type: "command", command: "\($hook) \($arg)", async: $async}]};
    def ours: [
      {event: "SessionStart",     entry: entry("start";  true)},
      {event: "UserPromptSubmit", entry: entry("prompt"; true)},
      # Sync, so a late tool hook can never land after Stop and undo "done".
      {event: "PostToolUse",      entry: entry("tool";   false)},
      {event: "Notification",     entry: entry("notify"; true)},
      {event: "Stop",             entry: entry("stop";   true)},
      {event: "SessionEnd",       entry: entry("end";    false)}
    ];
    .hooks //= {}
    | .hooks |= with_entries(.value |= map(select(.hooks | all(.command | contains("cct-hook") | not)))
                             | select(.value | length > 0))
    | if $mode == "install"
      then reduce ours[] as $o (.; .hooks[$o.event] += [$o.entry])
      else . end
  ' <<<"$current" > "$SETTINGS.tmp"
  mv "$SETTINGS.tmp" "$SETTINGS"
}

if [ "${1:-}" = "--uninstall" ]; then
  write_hooks uninstall
  plugin_dir="$(swiftbar_plugin_dir)"
  rm -f "$plugin_dir/cct.sh"
  echo "Removed cct hooks and plugin. Settings backup: $SETTINGS.cct-backup"
  exit 0
fi

check_prerequisites
plugin_dir="$(swiftbar_plugin_dir)"
chmod +x "$REPO"/bin/* "$REPO/plugin/cct.sh"
ln -sf "$REPO/plugin/cct.sh" "$plugin_dir/cct.sh"
write_hooks install
open -g "swiftbar://refreshallplugins" || true
echo "Installed. Hooks added to $SETTINGS (backup: $SETTINGS.cct-backup)"
echo "Plugin linked into $plugin_dir"
