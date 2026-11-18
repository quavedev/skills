#!/usr/bin/env bash
# publish-safety-check guard: scans git content for secrets, machine details and personal data.
#
#   guard.sh --staged            staged changes (pre-commit hook)
#   guard.sh --unpushed [ref]    commits on ref (default HEAD) not on any remote: diffs, messages, authors
#   guard.sh --all               every commit on every branch, plus messages and authors
#
# Exit 1 when a BLOCK finding exists, 0 otherwise (WARN findings are printed but do not fail).
# A line containing "guard:allow" is skipped. Personal terms to block live in
# ~/.config/publish-guard/denylist (one fixed string per line, # comments), never in the repo.

set -uo pipefail

DENYLIST="${PUBLISH_GUARD_DENYLIST:-$HOME/.config/publish-guard/denylist}"
mode="${1:---staged}"
ref="${2:-HEAD}"

blocks=0
warns=0
report() { # level where message
  if [ "$1" = BLOCK ]; then blocks=$((blocks + 1)); else warns=$((warns + 1)); fi
  printf '  [%s] %s: %s\n' "$1" "$2" "$3"
}

# --- what to scan -----------------------------------------------------------
diff_cmd=()
log_args=()
case "$mode" in
  --staged)   diff_cmd=(git diff --cached -U0 --no-color --no-ext-diff) ;;
  --unpushed) log_args=("$ref" --not --remotes) ;;
  --all)      log_args=(--all) ;;
  -h|--help)  sed -n '2,12p' "$0"; exit 0 ;;
  *) echo "guard: unknown mode $mode" >&2; exit 2 ;;
esac
[ ${#log_args[@]} -gt 0 ] && diff_cmd=(git log -p -U0 --no-color --no-ext-diff --format='commit %h' "${log_args[@]}")

# Added lines as "commit<TAB>path<TAB>line<TAB>text".
added=$("${diff_cmd[@]}" 2>/dev/null | awk '
  /^commit [0-9a-f]+$/ { c = $2; next }
  /^\+\+\+ /           { f = substr($0, 5); sub(/^b\//, "", f); next }
  /^@@/                { match($0, /\+[0-9]+/); n = substr($0, RSTART + 1, RLENGTH - 1) + 0; next }
  /^\+/                { print c "\t" f "\t" n "\t" substr($0, 2); n++ }
' | grep -v 'guard:allow')

# Files added or changed.
if [ "$mode" = --staged ]; then
  files=$(git diff --cached --name-only --diff-filter=ACMR)
else
  files=$(git log --format= --name-only --diff-filter=ACMR "${log_args[@]}" | sort -u)
fi

# --- content patterns ---------------------------------------------------------
texts=$(printf '%s\n' "$added" | cut -f4-)
where_of() { # Nth added line -> "commit path:line"
  printf '%s\n' "$added" | sed -n "${1}p" | awk -F'\t' '{ print ($1 ? $1 " " : "") $2 ":" $3 }'
}
scan() { # level label regex [grep flags] [exclude regex]
  local n text
  while IFS=: read -r n text; do
    [ -z "$n" ] && continue
    [ -n "${5:-}" ] && printf '%s' "$text" | grep -qE -- "$5" && continue
    report "$1" "$(where_of "$n")" "$2 -> $(printf '%s' "$text" | cut -c1-120)"
  done < <(printf '%s\n' "$texts" | grep -nE ${4:-} -- "$3" | head -5)
}

if [ -n "$added" ]; then
  scan BLOCK "private key"            '-----BEGIN ([A-Z]+ )*PRIVATE KEY-----'
  scan BLOCK "AWS access key"         'AKIA[0-9A-Z]{16}'
  scan BLOCK "GitHub token"           '(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{50,})'
  scan BLOCK "Slack token"            'xox[abprs]-[A-Za-z0-9-]{10,}'
  scan BLOCK "OpenAI/Anthropic key"   'sk-(ant-|proj-)?[A-Za-z0-9_-]{24,}'
  scan BLOCK "Google API key"         'AIza[0-9A-Za-z_-]{35}'
  scan BLOCK "Stripe live key"        '[rs]k_live_[0-9A-Za-z]{20,}'
  scan BLOCK "JWT"                    'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  scan BLOCK "credentials in URL"     '[a-z][a-z0-9+.-]*://[^/[:space:]:@]+:[^/[:space:]@]+@'
  scan BLOCK "home directory path"    "(/home/|/Users/|Users\\\\+)$(whoami)"
  scan BLOCK "machine hostname"       "$(hostname | sed 's/[.[\*^$()+?{|]/\\&/g')" -i
  scan WARN  "hard-coded secret"      '(password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]]{8,}' -i
  scan WARN  "private IP address"     '(^|[^0-9.])(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}([^0-9.]|$)'
  scan WARN  "email address"          '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
  scan WARN  "other user home path"   '(/home/|/Users/)[a-z_][a-z0-9_-]+/' "" "(/home/|/Users/)$(whoami)"
fi

# --- personal denylist (content, messages, authors) ----------------------------
deny_terms=()
if [ -f "$DENYLIST" ]; then
  while IFS= read -r t; do
    t="${t%%#*}"; t="$(printf '%s' "$t" | sed 's/[[:space:]]*$//')"
    [ -n "$t" ] && deny_terms+=("$t")
  done <"$DENYLIST"
fi
for t in "${deny_terms[@]}"; do
  while IFS=: read -r n _; do
    [ -n "$n" ] && report BLOCK "$(where_of "$n")" "denylisted term \"$t\""
  done < <(printf '%s\n' "$texts" | grep -niF -- "$t" | head -5)
done

if [ ${#log_args[@]} -gt 0 ]; then
  meta=$(git log --format='%h%x09%an <%ae> | %cn <%ce>%x09%B%x1e' "${log_args[@]}")
  for t in "${deny_terms[@]}"; do
    hit=$(printf '%s' "$meta" | tr '\036' '\n' | grep -iF -- "$t" | head -3)
    [ -n "$hit" ] && report BLOCK "commit metadata" "denylisted term \"$t\" in author or message: $(printf '%s' "$hit" | head -1 | cut -c1-120)"
  done
  home_hit=$(printf '%s' "$meta" | grep -E "(/home/|/Users/)$(whoami)" | head -1)
  [ -n "$home_hit" ] && report BLOCK "commit message" "home directory path: $(printf '%s' "$home_hit" | cut -c1-120)"
fi

# --- risky files -----------------------------------------------------------------
while IFS= read -r f; do
  [ -z "$f" ] && continue
  base="${f##*/}"
  case "$base" in
    .env.example|.env.sample|.env.template|.env.dist) ;;
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|*.jks|*.keystore|*.kdbx|id_rsa*|id_ed25519*|id_ecdsa*|.netrc|.pgpass|credentials.json|service-account*.json)
      report BLOCK "$f" "sensitive file type" ;;
    *.sqlite|*.sqlite3|*.db|*.dump|*.bak|*.log|.DS_Store|*.har)
      report WARN "$f" "may contain local data" ;;
  esac
  case "$base" in
    *.png|*.PNG|*.jpg|*.jpeg|*.JPG|*.JPEG|*.webp|*.tif|*.tiff|*.heic)
      if [ "$mode" = --staged ]; then blob=":$f"; else blob="$(git log -1 --format=%H "${log_args[@]}" -- "$f"):$f"; fi
      if git cat-file -p "$blob" 2>/dev/null | head -c 65536 | LC_ALL=C grep -aqE 'tEXt|iTXt|zTXt|eXIf|Exif|GPS|<x:xmpmeta'; then
        report WARN "$f" "image has text/EXIF/XMP metadata, check it (exiftool) or strip it"
      fi ;;
  esac
done <<<"$files"

# --- verdict -------------------------------------------------------------------------
if [ "$blocks" -gt 0 ]; then
  echo "publish-guard: $blocks blocking finding(s), $warns warning(s). Fix them, mark a false positive with 'guard:allow', or bypass once with --no-verify." >&2
  exit 1
fi
[ "$warns" -gt 0 ] && echo "publish-guard: $warns warning(s), nothing blocking." >&2
exit 0
