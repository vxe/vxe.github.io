# Blog — Claude instructions

Hugo blog for short, practical write-ups of investigations (Linux, StumpWM,
Emacs, Claude work). Deploys to GitHub Pages at **https://vijayedw.in/** on push
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
- `static/CNAME` — custom domain, survives Hugo rebuilds
- `.github/workflows/hugo.yml` — build + deploy to Pages
