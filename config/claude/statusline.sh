#!/bin/bash
# Claude Code status line: model + context-usage progress bar, right-aligned,
# plus Claude.ai rate-limit windows (5h / 7d) when the subscription exposes them.
# Receives session JSON on stdin; context_window.used_percentage is pre-calculated.
input=$(cat)

RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'

# Echo the threshold color for a percentage: green <70, yellow 70-89, red 90+.
pick_color() {
  if   [ "$1" -ge 90 ]; then printf '\033[31m'      # red
  elif [ "$1" -ge 70 ]; then printf '\033[33m'      # yellow
  else                       printf '\033[38;5;154m' # lime
  fi
}

# Determine tier color based on model name: Sonnet=magenta, Opus=yellow, Fable=green, Haiku=cyan
get_tier_color() {
  local model=$1

  if [[ $model == *"Sonnet"* ]]; then
    printf '\033[35m'  # magenta
  elif [[ $model == *"Opus"* ]]; then
    printf '\033[33m'  # yellow
  elif [[ $model == *"Fable"* ]]; then
    printf '\033[32m'  # green
  else  # Haiku or other
    printf '\033[36m'  # cyan
  fi
}

# Compact "resets in" countdown from an epoch reset time and now.
fmt_reset() {
  local rem=$(( $1 - $2 ))
  if   [ "$rem" -ge 86400 ]; then printf '%dd%dh' $((rem/86400)) $(((rem%86400)/3600))
  elif [ "$rem" -ge 3600 ];  then printf '%dh%dm' $((rem/3600)) $(((rem%3600)/60))
  elif [ "$rem" -gt 0 ];     then printf '%dm' $((rem/60))
  else                            printf 'now'
  fi
}

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
MODEL="${MODEL/ context)/)}"   # "Opus 4.8 (1M context)" -> "Opus 4.8 (1M)"
TIER_COLOR=$(get_tier_color "$MODEL")
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
[ -z "$PCT" ] && PCT=0

# Rate-limit windows: "// empty" so absent windows (non-subscriber, or pre-first
# API response) yield empty strings and get dropped silently below.
FIVE_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
FIVE_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' | cut -d. -f1)
WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' | cut -d. -f1)
NOW=$(date +%s)

WIDTH=12
FILLED=$((PCT * WIDTH / 100))
[ "$FILLED" -gt "$WIDTH" ] && FILLED=$WIDTH
EMPTY=$((WIDTH - FILLED))

printf -v FILL "%${FILLED}s"
printf -v PAD  "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

# Threshold colors: green <70, yellow 70-89, red 90+
COLOR=$(pick_color "$PCT")

# Colored (rendered) and plain (for length measurement) versions of the line.
COLORED=$(printf "%s%s%s%s %s%s%s %s%d%%%s ctx" \
  "$TIER_COLOR" "$BOLD" "$MODEL" "$RESET" \
  "$COLOR" "$BAR" "$RESET" \
  "$COLOR" "$PCT" "$RESET")
PLAIN="${MODEL} ${BAR} ${PCT}% ctx"

# Append a rate-limit window segment (label + colored % + reset countdown) when present.
append_window() {
  local label=$1 pct=$2 reset=$3 c countdown
  [ -z "$pct" ] && return
  c=$(pick_color "$pct")
  if [ -n "$reset" ]; then
    countdown=" ($(fmt_reset "$reset" "$NOW"))"
  else
    countdown=""
  fi
  COLORED+=$(printf "  %s %s%d%%%s%s" "$label" "$c" "$pct" "$RESET" "$countdown")
  PLAIN+="  ${label} ${pct}%${countdown}"
}
append_window "5h" "$FIVE_PCT" "$FIVE_RESET"
append_window "7d" "$WEEK_PCT" "$WEEK_RESET"

# Terminal width. Claude Code runs this with stdin as a pipe, no controlling
# terminal and no COLUMNS, so tput alone always reports the 80-column default.
# Walk up the process tree to the terminal Claude Code itself is attached to
# and ask that device for its real size.
term_cols() {
  local p=$PPID tt n=0 cols
  while [ -n "$p" ] && [ "$p" -gt 1 ] && [ "$n" -lt 10 ]; do
    tt=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
    if [ -n "$tt" ] && [ "$tt" != "?" ] && [ -r "/dev/$tt" ]; then
      cols=$(stty size < "/dev/$tt" 2>/dev/null | awk '{print $2}')
      [ -n "$cols" ] && [ "$cols" -gt 0 ] 2>/dev/null && { printf '%s' "$cols"; return 0; }
    fi
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    n=$((n + 1))
  done
  return 1
}

COLS=${COLUMNS:-0}
[ "$COLS" -gt 0 ] 2>/dev/null || COLS=$(term_cols) || COLS=$(tput cols 2>/dev/null)
[ -n "$COLS" ] && [ "$COLS" -gt 0 ] 2>/dev/null || COLS=80

# Left-pad so the visible text sits flush right (small right margin).
VIS=${#PLAIN}
PADLEN=$((COLS - VIS - 1))
[ "$PADLEN" -lt 0 ] && PADLEN=0
printf -v SPACES "%${PADLEN}s" ""

printf "%s%s\n" "$SPACES" "$COLORED"
