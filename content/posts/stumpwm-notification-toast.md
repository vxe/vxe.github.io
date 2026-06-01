---
title: "[stumpwm] A notification toast you can fire from anywhere"
date: 2026-06-02T00:10:00
draft: false
tags: [linux, stumpwm]
summary: "A macOS-style top-right toast for StumpWM, fireable from any shell — and wired so Claude pings me when a long task finishes."
---

StumpWM has no notification daemon by default — `notify-send` just errors with
`ServiceUnknown`. I didn't want the full freedesktop stack yet; I wanted one
small thing: a **macOS-style toast in the top-right** that I can fire from a
shell one-liner. Bonus: I wired it so Claude Code pings me when a long task
finishes, with a message describing *what* finished.

![A top-right toast reading "build complete: 142 tests green"](/img/notify-toast.png)

## The command

This builds on the [polybar → StumpWM eval bridge](/2026/06/stumpwm-clickable-polybar-labels-that-open-a-stumpwm-menu/)
from the last post. The notification itself is just a StumpWM command:

```lisp
(defcommand notify (text) ((:string "notify: "))
  "Top-right toast. The message is deferred onto a 0-delay timer rather than
shown directly — see below for why."
  (let ((msg text))
    (run-with-timer 0 nil
      (lambda ()
        (let ((*message-window-gravity* :top-right))
          (message "~a" msg))))))
```

Two deliberate choices:

- **`let`-bound gravity, not global.** Binding `*message-window-gravity*` locally
  means notifications go top-right while my normal (centered) command feedback is
  untouched.
- **The `run-with-timer 0` is the whole trick** — and the reason for it is the
  good part.

## The bug that needed the timer

My first version called `(message ...)` directly. It worked when I triggered it
through the eval bridge (a file the watcher polls), but **vanished instantly**
when I triggered the same command through `stumpish` (StumpWM's standard IPC,
which sets an X property StumpWM reads).

Same command, same message, different trigger — one showed, one didn't. The
command was definitely running (its return value came back fine). The difference:
when a command runs via the `STUMPWM_COMMAND` IPC, StumpWM's **command-completion
clears the message window** right after the command returns. A message painted
*inside* that command gets wiped a millisecond later. The bridge path (a timer
callback) isn't a "command", so it was never cleared.

Deferring the message onto `(run-with-timer 0 …)` paints it **one event-loop tick
later** — after the completion-clear — so it now survives on both paths.

## Firing it

Two ways, both work now:

```bash
# Portable: StumpWM's standard IPC (needs `stumpish` from stumpwm-contrib + xprop)
stumpish notify "build complete: 142 tests green"

# The eval bridge (a file the WM polls) — UTF-8 safe
echo '(notify "build complete: 142 tests green")' > /tmp/stumpwm-eval-input
```

One gotcha: `stumpish` ships the command in an **8-bit X property**, so non-ASCII
(a `✓`, an emoji) gets corrupted in transit and the command silently drops. Keep
stumpish messages ASCII; the file bridge handles UTF-8 fine. (The message *font*
also lacks many glyphs, rendering them as `?` — another reason to stay plain.)

## Wiring it to Claude

The payoff: a line in my global agent config tells Claude Code to fire a toast
when a long task wraps up, with a contextual message:

```
When a genuinely long-running task finishes (builds, full test suites), run:
  echo '(notify "<short description>")' > /tmp/stumpwm-eval-input
```

Now a long build or test run ends with a top-right toast like the one above —
no terminal-watching required. Next stop: a real `org.freedesktop.Notifications`
daemon so *every* app routes through the same toast.
