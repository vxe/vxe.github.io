# Blog — Claude instructions

Hugo blog for short, practical write-ups of investigations (Linux, StumpWM,
Emacs, Claude work). Deploys to GitHub Pages at **https://vxe.github.io/** on push
to `main`. Source lives here in `~/Documents/blog` (cron-mirrored to Dropbox).

## How to add a post ("blog this")

1. Write to `content/posts/<slug>.md` with `draft: true` and this front-matter:
   ```yaml
   ---
   title: "Sentence-case title"
   date: 2026-06-01        # today's date
   draft: true             # stays out of the build until reviewed
   tags: [linux, polybar]
   summary: "One-line hook shown on the home page."
   ---
   ```
2. Keep the voice **concise and practical**: a one-paragraph hook, then the
   thing + code. No long theory the reader will argue about — show, don't
   lecture. (See the first post as the template.)
3. Run the security gate: `make scrub` (also runs automatically on commit).
4. Leave it `draft: true` for the human to review.

## Adding screenshots (X11 / StumpWM desktop)

The agent can capture the screen and **actually see it**: shoot a PNG with
`maim`, then `Read` the file (Read renders images). Use this to caption what is
really on screen, not a guess. Install once: `sudo apt install -y maim slop`.

Capture recipes (set `DISPLAY=:0` if unset):

```bash
maim /tmp/shot.png                                       # whole screen
maim --window "$(xdotool getactivewindow)" /tmp/w.png    # focused window
maim --geometry WxH+X+Y /tmp/region.png                  # exact screen rectangle
maim --select /tmp/r.png                                 # drag a region (slop)
```

Locate a polybar widget precisely: `xdotool search --class polybar` →
`xdotool getwindowgeometry --shell <wid>` for the bar's box, then grab a
sub-rectangle with `--geometry` and **`Read` it to verify the crop**, tightening
coordinates until only the intended widget is in frame. Iterate — you can see
each attempt.

**Crop to the subject — a screenshot bypasses the scrub gate.** `scrub.sh`
scans text, not PNG pixels, so a full-bar/full-screen shot can publish a network
interface name, IP, hostname, location/timezone, window titles, or open content
that the gate would otherwise block. Capture only the widget/window the post is
about; never commit a full-screen grab without eyeballing every pixel for PII.

Store + link: put files in `static/img/<name>.png` (served at `/img/...`) and
reference with markdown `![alt](/img/<name>.png)`. Rebuild and confirm the
`<img>` is in the built page and serves 200 before handing off.

If you toggle live system state to stage a shot (e.g. flipping a feature on),
**restore it afterward** — leave the machine as you found it.

### Capturing a StumpWM menu / popup (override-redirect windows)

`maim --window` and `--geometry` **miss** StumpWM menus (e.g. `select-from-menu`)
— they're override-redirect windows the WM paints itself, and they grab the
keyboard, so per-window capture and focus-stealing both fail. What works:

1. **Trigger it** the same way the UI does. Clickable polybar labels write a Lisp
   form to the eval bridge, so reproduce that: `echo '(some-command)' >
   /tmp/stumpwm-eval-input` (the watcher polls every ~2s).
2. **Full-screen `maim`** — the centered menu is part of the screen. The menu
   *blocks* (interactive), so it stays up; no timing race.
3. **Crop with ImageMagick** (installed): `convert full.png -crop WxH+X+Y +repage
   out.png`, then `Read` and adjust — iterate on the saved PNG, no re-trigger
   needed. (`maim --geometry` is unreliable here: tiling/overlap moves things.)
4. **Abort cleanly**: `xdotool key Escape` then `ctrl+g`. Arrow-key *navigation*
   via xdotool is unreliable (synthetic keys often don't reach the grab) — don't
   rely on it.
5. **Back up + restore** any state the menu would change (e.g. the timezone
   file), and confirm it's unchanged after.

Useful `select-from-menu` facts: it supports **type-to-filter** (default
`filter-pred`, case-sensitive — type `Los`, not `los`) to narrow a long list for
a clean shot, and takes an `initial-selection` index as its 4th arg. Use the eval
bridge to compute things (e.g. `(position "America/Los_Angeles" (list-…) …)`),
reading the result from `/tmp/stumpwm-eval-output`.

## Publishing (human-in-the-loop)

- Review the draft, then: `make publish POST=content/posts/<slug>.md`
  (flips `draft: false`).
- `git add -A && git commit && git push` → CI builds and deploys.
- **Never auto-publish.** Drafts are reviewed first, always.

## Security gate — non-negotiable 🚩

The repo is pushed to GitHub, so committed markdown is effectively public even
while `draft: true`. A pre-commit hook (`scripts/scrub.sh`) blocks commits
containing secrets or personal identifiers. **Do not bypass it.**

When writing posts, pre-scrub by convention:
- real home paths → `~` (never `/home/<user>`)
- device serials, MAC/IP addresses → `<redacted>` / placeholders
- emails, tokens, API keys → removed entirely
- private internals (RCA details, infra hostnames) → generalize or omit

If the gate fires, fix the content — do not use `--no-verify`.

⚠️ **The gate scans text only — images bypass it entirely.** Any screenshot is
your responsibility to vet pixel-by-pixel for PII before committing (see
"Adding screenshots"). Prefer tight crops of just the subject.

Personal identifiers (home path, email, device serial) are **not** in the
committed `scrub.sh` — they live in `scripts/scrub.local`, which is gitignored
so the gate itself never publishes PII. Set it up once from
`scripts/scrub.local.example`. Generic secret patterns stay in `scrub.sh`.

## Commands

| Command | Does |
|---|---|
| `make serve` | local preview at :1313 (shows drafts) |
| `make new NEW=slug` | scaffold a new draft |
| `make scrub` | run the security gate manually |
| `make publish POST=...` | flip a draft live |
| `make install-hooks` | (re)activate the pre-commit gate |

## Layout

- `content/posts/` — all posts (`draft:` flag controls visibility)
- `layouts/` — self-contained minimal theme (no external theme dependency)
- `.github/workflows/hugo.yml` — build + deploy to Pages

Served free at `https://vxe.github.io/` (repo is named `vxe.github.io`). To use a
custom domain later: add `static/CNAME` with the domain, set `baseURL` in
`hugo.toml` to match, and point the domain's DNS at GitHub Pages
(`185.199.108–111.153`).
