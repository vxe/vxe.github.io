#!/usr/bin/env bash
# Security gate for the blog. Refuses content containing secrets or personal
# identifiers. Pure bash/grep — no external deps. Used by the pre-commit hook
# and by `make scrub`.
#
#   ./scripts/scrub.sh            # scan staged changes (pre-commit)
#   ./scripts/scrub.sh FILE...    # scan specific files
set -uo pipefail

if [[ $# -gt 0 ]]; then
  FILES=("$@")
else
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
fi
[[ ${#FILES[@]} -eq 0 ]] && { echo "scrub: nothing to scan"; exit 0; }

# name=ERE-pattern. Secrets + vxe's personal identifiers. Extend as needed.
PATTERNS=(
  "AWS access key=AKIA[0-9A-Z]{16}"
  "GitHub token=gh[pousr]_[A-Za-z0-9]{36,}"
  "GitHub fine-grained PAT=github_pat_[A-Za-z0-9_]{50,}"
  "OpenAI/Anthropic key=sk-(ant-)?[A-Za-z0-9_-]{20,}"
  "Slack token=xox[baprs]-[A-Za-z0-9-]{10,}"
  "Private key block=BEGIN [A-Z ]*PRIVATE KEY"
  "Bearer token=[Bb]earer [A-Za-z0-9._-]{20,}"
  "Secret assignment=(password|passwd|secret|api[_-]?key|access[_-]?token)[\"' ]*[:=][\"' ]*[A-Za-z0-9/+_.-]{8,}"
)

# Personal identifiers (home path, email, device serial, …) live in a
# GITIGNORED local file so this committed script contains ZERO PII.
# Copy scrub.local.example -> scrub.local and fill in real values.
LOCAL="$(dirname "${BASH_SOURCE[0]}")/scrub.local"
if [[ -f "$LOCAL" ]]; then
  while IFS= read -r ln; do
    [[ -z "$ln" || "$ln" == \#* ]] && continue
    PATTERNS+=("$ln")
  done < "$LOCAL"
fi

hits=0
for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || continue
  # Skip only the gitignored local pattern file (it holds the PII patterns).
  case "$f" in *scripts/scrub.local) continue ;; esac
  for entry in "${PATTERNS[@]}"; do
    name="${entry%%=*}"; pat="${entry#*=}"
    matches="$(grep -nEI "$pat" "$f" 2>/dev/null)" || true
    if [[ -n "$matches" ]]; then
      while IFS= read -r m; do
        echo "  ✗ [$name] $f:$m"
        hits=$((hits+1))
      done <<< "$matches"
    fi
  done
done

if [[ $hits -gt 0 ]]; then
  echo
  echo "scrub: BLOCKED — $hits potential leak(s) above. Redact, then re-commit."
  echo "       false positive? tune scripts/scrub.sh, or 'git commit --no-verify' ONLY if certain."
  exit 1
fi
echo "scrub: clean ✓"
