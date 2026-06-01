---
title: "[stumpwm] A clickable \"stay awake\" toggle for Polybar"
date: 2026-06-01
draft: false
tags: [linux, polybar, stumpwm]
summary: "A coffee-cup button that blocks both systemd and X sleep — click on, click off."
---

I missed macOS's Amphetamine on Linux, so I added a little coffee cup to my
Polybar. Click it and the machine stays awake — no idle sleep, no screen
blanking. Click again and it's back to normal. Moon = normal, coffee =
caffeinated.

![Polybar showing the muted moon "auto" state](/img/caffeine-auto.png)
![Polybar showing the accent coffee-cup "awake" state](/img/caffeine-awake.png)

(Off, then on — the icon and colour both flip.)

The one thing most "caffeine" snippets miss: there are **two** layers that put a
Linux box to sleep, and you have to inhibit both — systemd/logind idle+sleep,
and X11's screensaver + DPMS blanking. Kill only one and the box still dozes off
on you.

The second subtlety is *restoring* state. Most snippets just do `xset s on
+dpms` when you turn the toggle off — which silently resets your blanking
timeouts to whatever defaults `xset` feels like, not what you actually had. So
this version snapshots your real screensaver + DPMS timeouts on the way in and
puts them back exactly on the way out.

## The script

`~/.config/polybar/caffeine.sh` (then `chmod +x`):

```bash
#!/usr/bin/env bash
# caffeine.sh — Amphetamine-style keep-awake toggle for StumpWM / Polybar.
#
# Inhibits BOTH layers that put this box to sleep:
#   1. systemd/logind  — idle + sleep  (via a held `systemd-inhibit` process)
#   2. X11             — screensaver + DPMS blanking (via `xset`)
#
# State lives in a pidfile, so Polybar, a StumpWM command, and the CLI all
# share one source of truth and survive a bar/WM reload.
#
# usage: caffeine.sh {on|off|toggle|status}
set -uo pipefail

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="$RUNTIME/caffeine.pid"
XSETFILE="$RUNTIME/caffeine.xset"        # saved DPMS/screensaver state, for exact restore
export DISPLAY="${DISPLAY:-:0}"

is_active() {
  [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null
}

save_xset() {
  # Capture current screensaver + DPMS timeouts so `off` restores them exactly.
  local q
  q="$(xset q 2>/dev/null || true)"
  {
    echo "ss_to=$(awk '/timeout:/{print $2; exit}' <<<"$q")"
    echo "ss_cy=$(awk '/timeout:/{print $4; exit}' <<<"$q")"
    echo "st=$(awk '/Standby:/{print $2; exit}' <<<"$q")"
    echo "su=$(awk '/Standby:/{print $4; exit}' <<<"$q")"
    echo "of=$(awk '/Standby:/{print $6; exit}' <<<"$q")"
  } >"$XSETFILE"
}

activate() {
  is_active && return 0
  save_xset
  xset s off -dpms 2>/dev/null || true                 # stop X blanking now
  nohup systemd-inhibit \
        --what=idle:sleep \
        --who=caffeine \
        --why="keep-awake toggle" \
        --mode=block \
        sleep infinity >/dev/null 2>&1 &
  echo $! >"$PIDFILE"
}

deactivate() {
  if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null || true   # SIGTERM, releases the inhibitor
    rm -f "$PIDFILE"
  fi
  if [[ -f "$XSETFILE" ]]; then
    # shellcheck disable=SC1090
    source "$XSETFILE"
    xset s "${ss_to:-600}" "${ss_cy:-600}" 2>/dev/null || true
    xset +dpms 2>/dev/null || true
    xset dpms "${st:-600}" "${su:-600}" "${of:-600}" 2>/dev/null || true
    rm -f "$XSETFILE"
  else
    xset s 600 600 +dpms 2>/dev/null || true                   # fall back to observed defaults
    xset dpms 600 600 600 2>/dev/null || true
  fi
}

status() {
  if is_active; then
    echo '%{F#ffcc00}%{T3}󰅶%{T-} awake%{F-}'      # coffee, accent
  else
    echo '%{F#888899}%{T3}󰒲%{T-} auto%{F-}'       # moon, muted
  fi
}

case "${1:-status}" in
  on)     activate ;;
  off)    deactivate ;;
  toggle) if is_active; then deactivate; else activate; fi ;;
  status) status ;;
  *)      echo "usage: $0 {on|off|toggle|status}" >&2; exit 1 ;;
esac
```

A few things worth calling out:

- **The inhibitor is a held process, not a flag.** `systemd-inhibit … sleep
  infinity` takes the lock for as long as that `sleep` lives; we stash its PID
  and `kill` it to release. `--mode=block` makes it a hard block, not a delay.
- **`save_xset` / restore** is the part most snippets skip. `xset q` is parsed
  on the way in, written to a sidecar file, and replayed verbatim on the way
  out — so toggling off returns you to *your* timeouts, not a guess.
- **Four verbs, one state file.** `on`/`off`/`toggle`/`status` all read the same
  pidfile, so Polybar, a StumpWM keybinding, and the shell never disagree about
  whether you're caffeinated.

## The Polybar module

```ini
[module/caffeine]
; Amphetamine-style keep-awake toggle. Left-click flips it; the script's own
; %{F..} markup colours the label (accent=awake, muted=auto-sleep).
type     = custom/script
exec     = ~/.config/polybar/caffeine.sh status
interval = 2
format   = %{A1:~/.config/polybar/caffeine.sh toggle:}<label>%{A}
```

Add `caffeine` to your `modules-right` and you're done. The icons are Nerd Font
(`nf-md-coffee` / `nf-md-sleep`), wrapped in `%{T3}` so Polybar pulls them from
your icon font; the script emits the colour markup itself so the label changes
appearance without any extra Polybar config.

## Bonus: bind it in StumpWM

Because `toggle` is just a CLI verb sharing the same state, you can flip it from
a keybinding too — the bar updates within its 2-second poll:

```lisp
(define-key *top-map* (kbd "s-C")
  "run-shell-command caffeine.sh toggle")
```

The pidfile is the whole trick: the bar, the click handler, and the keybinding
are three faces of one source of truth, and all of it survives a bar or WM
reload.
