#!/usr/bin/env bash
# <xbar.title>cct — Claude Code sessions</xbar.title>
# <xbar.desc>Lists Claude Code sessions in Ghostty and pulses when one needs you.</xbar.desc>
# <xbar.dependencies>jq,ghostty</xbar.dependencies>
# <swiftbar.type>streamable</swiftbar.type>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

STATE_DIR="${CCT_STATE_DIR:-$HOME/.cct/sessions}"
# Resolve the symlink SwiftBar loads us through, to find bin/ in the repo.
FOCUS="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/bin/cct-focus"
TICK=0.6
mkdir -p "$STATE_DIR"

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

# One TSV row per session, most urgent first.
sessions() {
  cat "$STATE_DIR"/*.json 2>/dev/null | jq -rs '
    def rank: {waiting: 0, done: 1, busy: 2, idle: 3}[.status] // 4;
    map(select(.session_id and .cwd and .status))
    | sort_by(rank, -.updated)[]
    | [.session_id, .status, (.cwd | split("/") | last), (.prompt // ""), .updated] | @tsv'
}

render() {
  local frame=$1 rows waiting done
  rows="$(sessions)"
  waiting="$(grep -c $'\twaiting\t' <<<"$rows")"
  done="$(grep -c $'\tdone\t' <<<"$rows")"

  echo "~~~"
  if [ "$waiting" -gt 0 ]; then
    [ $((frame % 2)) -eq 0 ] && echo "$waiting | sfimage=exclamationmark.bubble.fill sfcolor=#FF9500" \
                             || echo "$waiting | sfimage=exclamationmark.bubble"
  elif [ "$done" -gt 0 ]; then
    [ $((frame % 2)) -eq 0 ] && echo "$done | sfimage=checkmark.bubble.fill sfcolor=#34C759" \
                             || echo "$done | sfimage=checkmark.bubble"
  else
    echo " | sfimage=bubble.left.and.text.bubble.right"
  fi
  echo "---"

  if [ -z "$rows" ]; then
    echo "No Claude sessions | color=gray"
    return
  fi
  local sid status repo prompt updated icon color
  while IFS=$'\t' read -r sid status repo prompt updated; do
    case "$status" in
      waiting) icon=exclamationmark.bubble.fill; color=#FF9500 ;;
      done)    icon=checkmark.circle.fill;       color=#34C759 ;;
      busy)    icon=ellipsis.circle;             color=#0A84FF ;;
      *)       icon=circle;                      color=#8E8E93 ;;
    esac
    echo "$repo  ·  $status $(age "$updated") | sfimage=$icon sfcolor=$color bash=$FOCUS param1=$sid terminal=false"
    [ -n "$prompt" ] && echo "-- ${prompt//|/¦} | size=11 color=gray"
  done <<<"$rows"
}

frame=0
last=""
while true; do
  prune
  out="$(render "$frame")"
  # Only redraw on change, so an open menu doesn't flicker.
  if [ "$out" != "$last" ]; then
    echo "$out"
    last="$out"
  fi
  frame=$((frame + 1))
  sleep "$TICK"
done
