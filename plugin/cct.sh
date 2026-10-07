#!/usr/bin/env bash
# <xbar.title>cct — Claude Code Tracker</xbar.title>
# <xbar.version>v1.0.1</xbar.version>
# <xbar.author>Kalle Asad-Lundgren</xbar.author>
# <xbar.author.github>kallestorytel</xbar.author.github>
# <xbar.desc>Lists Claude Code sessions in Ghostty and shows which ones need you or are monitoring.</xbar.desc>
# <xbar.dependencies>jq,ghostty,claude</xbar.dependencies>
# <xbar.abouturl>https://github.com/kallestorytel/cct</xbar.abouturl>
# <swiftbar.type>streamable</swiftbar.type>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

STATE_DIR="${CCT_STATE_DIR:-$HOME/.cct/sessions}"
# Resolve the symlink SwiftBar loads us through, to find bin/ in the repo.
BIN="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/bin"
FOCUS="$BIN/cct-focus"
TICK=0.6
mkdir -p "$STATE_DIR"

# Icons are SF Symbol names; colors are hex. Override any of these in ~/.cct/config.
ICON=ipod.shuffle.gen1
COLOR_WAITING=#FF9500
COLOR_DONE=#34C759
COLOR_BUSY=#0A84FF
COLOR_IDLE=#8E8E93
CONFIG="${CCT_CONFIG:-$HOME/.cct/config}"
# shellcheck source=/dev/null
[ -f "$CONFIG" ] && source "$CONFIG"

age() {
  local s=$(( $(date +%s) - $1 ))
  if   [ "$s" -lt 60 ];   then echo "${s}s"
  elif [ "$s" -lt 3600 ]; then echo "$(( s / 60 ))m"
  else                         echo "$(( s / 3600 ))h"
  fi
}

# Drop sessions whose claude process is gone (crashes skip the SessionEnd hook).
prune() {
  local f pid
  for f in "$STATE_DIR"/*.json; do
    [ -e "$f" ] || continue
    pid="$(jq -r '.pid // empty' "$f" 2>/dev/null)"
    # No pid yet means a hook is still recording identity. Leave it; sessions() skips it.
    [ -n "$pid" ] || continue
    kill -0 "$pid" 2>/dev/null || rm -f "$f"
  done
}

# Ghostty's focused terminal id, or nothing when Ghostty isn't the frontmost app.
focused_terminal() {
  osascript -e 'tell application "Ghostty"
    if not frontmost then return ""
    return id of focused terminal of selected tab of front window
  end tell' 2>/dev/null
}

# A finished session you're already looking at needs no attention: mark it idle.
clear_seen() {
  local f sid focused
  # Only ask Ghostty when there's something to clear.
  grep -lq '"status": *"done"' "$STATE_DIR"/*.json 2>/dev/null || return 0
  focused="$(focused_terminal)"
  [ -n "$focused" ] || return 0
  for f in "$STATE_DIR"/*.json; do
    [ "$(jq -r '.status // empty' "$f" 2>/dev/null)" = "done" ] || continue
    sid="$(jq -r .session_id "$f")"
    if [ "$("$BIN/cct-probe" "$sid" 2>/dev/null)" = "$focused" ]; then
      jq 'if .status == "done" then .status = "idle" else . end' "$f" > "$f.$$.tmp" && mv "$f.$$.tmp" "$f"
    fi
  done
}

# Pids of claude processes that have Bash or Monitor commands running. Claude runs those through a
# shell that sources its shell snapshot. Outside a turn, that can only be background work.
background_parents() {
  ps -ax -o ppid=,command= | awk '/\/\.claude\/shell-snapshots\// { print $1 }' | sort -u | paste -sd, -
}

# One TSV row per session, most urgent first.
sessions() {
  cat "$STATE_DIR"/*.json 2>/dev/null | jq -rs --arg bg "$(background_parents)" '
    def rank: {waiting: 0, done: 1, busy: 2, idle: 3}[.status] // 4;
    ($bg | split(",") | map(tonumber? // empty)) as $bg
    | map(select(.session_id and .cwd and .status))
    | sort_by(rank, -.updated)[]
    | (.status != "busy" and (.pid as $p | $bg | index($p) != null)) as $monitoring
    | [.session_id, .status, (.cwd | split("/") | last), (.prompt // ""), .updated, $monitoring] | @tsv'
}

render() {
  local rows attention
  rows="$(sessions)"
  # Waiting and done both mean "go look", so the menu bar shows one count.
  attention="$(grep -cE $'\t(waiting|done)\t' <<<"$rows")"

  echo "~~~"
  if [ "$attention" -gt 0 ]; then
    echo "$attention | sfimage=$ICON"
  else
    echo " | sfimage=$ICON"
  fi
  echo "---"

  if [ -z "$rows" ]; then
    echo "No Claude sessions | color=gray"
    return
  fi
  local sid status repo prompt updated monitoring icon color label
  while IFS=$'\t' read -r sid status repo prompt updated monitoring; do
    case "$status" in
      waiting) icon=exclamationmark.bubble.fill; color=$COLOR_WAITING ;;
      done)    icon=checkmark.circle.fill;       color=$COLOR_DONE ;;
      busy)    icon=ellipsis.circle;             color=$COLOR_BUSY ;;
      *)       icon=circle;                      color=$COLOR_IDLE ;;
    esac
    label="$status $(age "$updated")"
    [ "$monitoring" = "true" ] && label="$label  ·  monitoring"
    # An inline :symbol: keeps its sfcolor in every menu state; sfimage tints get dimmed by macOS.
    echo ":$icon: $repo  ·  $label | sfcolor=$color bash=$FOCUS param1=$sid terminal=false"
    [ -n "$prompt" ] && echo "-- ${prompt//|/¦} | size=11 color=gray"
  done <<<"$rows"
}

last=""
while true; do
  prune
  clear_seen
  out="$(render)"
  # Only redraw on change, so an open menu doesn't flicker.
  if [ "$out" != "$last" ]; then
    echo "$out"
    last="$out"
  fi
  sleep "$TICK"
done
