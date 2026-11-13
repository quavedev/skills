#!/usr/bin/env bash
# Installs the publish guard as pre-commit and pre-push hooks in the current git repo.
# An existing hook that is not ours is kept as <hook>.local and still runs first.
#   install-guard.sh            install
#   install-guard.sh --remove   uninstall and restore any <hook>.local
set -euo pipefail

GUARD="$(cd "$(dirname "$0")" && pwd)/guard.sh"
hooks="$(git rev-parse --git-path hooks)"
mkdir -p "$hooks"
MARK="# publish-safety-check guard"

for hook in pre-commit pre-push; do
  path="$hooks/$hook"
  if [ "${1:-}" = --remove ]; then
    if [ -f "$path" ] && grep -qF "$MARK" "$path"; then
      rm "$path"; [ -f "$path.local" ] && mv "$path.local" "$path"
      echo "removed $hook"
    fi
    continue
  fi
  if [ -f "$path" ] && ! grep -qF "$MARK" "$path"; then
    mv "$path" "$path.local"; echo "kept existing $hook as $hook.local"
  fi
  if [ "$hook" = pre-commit ]; then scan='"$GUARD" --staged'; else scan='
while read -r _ local_sha _ _; do
  case "$local_sha" in *[!0]*) "$GUARD" --unpushed "$local_sha" || exit 1 ;; esac
done <<<"$INPUT"'; fi
  cat >"$path" <<EOF
#!/usr/bin/env bash
$MARK
GUARD="$GUARD"
INPUT=""; [ "$hook" = pre-push ] && INPUT="\$(cat)"
if [ -x "$path.local" ]; then printf '%s\n' "\$INPUT" | "$path.local" "\$@" || exit \$?; fi
if [ ! -x "\$GUARD" ]; then echo "publish-guard: \$GUARD missing, refusing. Reinstall or use --no-verify." >&2; exit 1; fi
$scan
EOF
  chmod +x "$path"
  echo "installed $hook -> $path"
done
