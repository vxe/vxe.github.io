---
title: "[stumpwm] Clickable Polybar labels that open a StumpWM menu"
date: 2026-06-01T12:00:00
draft: false
tags: [linux, polybar, stumpwm]
summary: "Click a Polybar label and have your window manager pop a native menu — via a tiny file-based eval bridge."
---

Polybar labels can be clickable — that's the `%{A1:…}` action syntax. The fun
part is wiring that click to your *window manager* so a click pops a native
StumpWM menu. Here's the date widget on my bar: click the city/time and you get
a timezone picker, type to filter, pick one, and the bar switches zones.

![The timezone menu — every zone, click the date to open it](/img/datepicker-menu.png)
![Type to filter the menu down to a city](/img/datepicker-los-angeles.png)

The trick is a three-hop bridge: **Polybar click → a file → a StumpWM eval
watcher**. Polybar can only run shell commands, and StumpWM lives in a separate
Lisp image, so the file is the mailbox between them.

## 1. The clickable Polybar module

`%{A1:CMD:}…%{A}` wraps the label in a left-click that runs `CMD`. All we do on
click is append a Lisp form to a well-known file:

```ini
[module/date]
type     = custom/script
exec     = ~/.config/polybar/date-display.sh
interval = 1
format   = %{A1:echo '(pick-date-city)' > /tmp/stumpwm-eval-input:}<label>%{A}
```

The label itself just prints the current city + time, reading the chosen zone
from a small state file:

```bash
#!/bin/bash
# date-display.sh
CITY_FILE="$HOME/.config/polybar/date-city"
[ -f "$CITY_FILE" ] || echo "Europe/London" > "$CITY_FILE"
TZ_NAME=$(cat "$CITY_FILE")
CITY="${TZ_NAME##*/}"; CITY="${CITY//_/ }"     # "America/Los_Angeles" → "Los Angeles"
TZ="$TZ_NAME" date "+$CITY %H:%M"
```

## 2. The eval bridge (StumpWM side)

StumpWM polls that file, reads one Lisp form, and evaluates it. The essence:

```lisp
(defvar *eval-input* "/tmp/stumpwm-eval-input")

(defun poll-eval-input ()
  (when (probe-file *eval-input*)
    (let ((form (with-open-file (s *eval-input*) (read s))))
      (delete-file *eval-input*)                 ; consume it
      (ignore-errors (eval form)))))

;; check a couple of times a second
(run-with-timer 0 2 #'poll-eval-input)
```

That's the whole idea. (My real version locks the file, captures the result to
an output file, and logs errors — but this is the load-bearing part.)

## 3. The command it runs

`pick-date-city` is an ordinary StumpWM command that shows a native menu of
timezones and writes your choice back to the state file the bar reads:

```lisp
(defcommand pick-date-city () ()
  "Pick a timezone for the Polybar date display."
  (let ((sel (select-from-menu (current-screen)
                               (list-system-timezones)   ; names under /usr/share/zoneinfo
                               "Timezone: ")))
    (when sel
      (with-open-file (s (merge-pathnames ".config/polybar/date-city"
                                          (user-homedir-pathname))
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
        (write-string sel s)))))
```

`select-from-menu` gives you arrow-key navigation **and** type-to-filter for
free (its default `filter-pred` matches as you type — that's the second
screenshot). Pick a city, the file updates, and the bar's 1-second poll shows the
new zone.

## One caveat worth stating

Anything that can write `/tmp/stumpwm-eval-input` runs code inside your window
manager. On a single-user machine that's just a convenient local bridge, but
it's a real trust boundary — don't point it at anything you don't control, and
keep the form you write to it simple and known (here, a fixed `(pick-date-city)`,
not arbitrary input).

The pattern generalizes: any Polybar module can now trigger any StumpWM
command — volume menus, window pickers, a "jump to workspace" list — by echoing
one form into the bridge.
