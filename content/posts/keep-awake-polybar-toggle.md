---
title: "A clickable \"stay awake\" toggle for Polybar"
date: 2026-06-01
draft: true
tags: [linux, polybar, stumpwm]
summary: "A coffee-cup button that blocks both systemd and X sleep — click on, click off."
---

I missed macOS's Amphetamine on Linux, so I added a little coffee cup to my
Polybar. Click it and the machine stays awake — no idle sleep, no screen
blanking. Click again and it's back to normal. Moon = normal, coffee =
caffeinated.

The one thing most "caffeine" snippets miss: there are **two** layers that put a
Linux box to sleep, and you have to inhibit both — systemd/logind idle+sleep,
and X11's screensaver + DPMS blanking.

## The script

`~/.config/polybar/caffeine.sh` (then `chmod +x`):

```bash
#!/usr/bin/env bash
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/caffeine.pid"
export DISPLAY="${DISPLAY:-:0}"
active() { [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

case "${1:-status}" in
  toggle)
    if active; then
      kill "$(cat "$PIDFILE")" 2>/dev/null; rm -f "$PIDFILE"
      xset s on +dpms
    else
      xset s off -dpms
      nohup systemd-inhibit --who=caffeine --why=stay-awake \
            --what=idle:sleep sleep infinity >/dev/null 2>&1 &
      echo $! >"$PIDFILE"
    fi ;;
  status)
    active && echo '%{F#ffcc00}󰅶 awake%{F-}' || echo '%{F#888899}󰒲 auto%{F-}' ;;
esac
```

## The Polybar module

```ini
[module/caffeine]
type     = custom/script
exec     = ~/.config/polybar/caffeine.sh status
interval = 2
format   = %{A1:~/.config/polybar/caffeine.sh toggle:}<label>%{A}
```

Add `caffeine` to your `modules-right` and you're done. Icons are Nerd Font
(`nf-md-coffee` / `nf-md-sleep`); the pidfile keeps the bar and the click in
sync and survives a bar reload.
