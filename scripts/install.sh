#!/usr/bin/env bash
# Link one harness's agents into that harness's user agent directory.
#
#   ./scripts/install.sh          # pi, the default
#   ./scripts/install.sh pi
#
# Pi discovers subagents from <pi agent dir>/agents, so the roster is linked
# rather than copied: editing this repo changes the running agents, and there
# is never a second copy to drift.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="${1:-pi}"

case "$HARNESS" in
  pi)
    TARGET="${PI_AGENTS_DIR:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/agents}"
    ;;
  *)
    echo "sassy-agents: unknown harness '$HARNESS' (supported: pi)" >&2
    exit 1
    ;;
esac

SRC="$REPO/$HARNESS"

if [ ! -d "$SRC" ]; then
  echo "sassy-agents: $SRC does not exist" >&2
  exit 1
fi

mkdir -p "$TARGET"

# One symlink per agent keeps the directory writable for personal agents.
for src in "$SRC"/*.md; do
  name="$(basename "$src")"
  dest="$TARGET/$name"

  if [ -L "$dest" ]; then
    ln -sfn "$src" "$dest"
    continue
  fi

  if [ -e "$dest" ]; then
    if cmp -s "$src" "$dest"; then
      # Identical copy from before this repo became the source of truth.
      rm "$dest"
      ln -s "$src" "$dest"
    else
      echo "sassy-agents: skipping $dest (exists and differs)" >&2
    fi
    continue
  fi

  ln -s "$src" "$dest"
done

echo "sassy-agents: linked $SRC/*.md into $TARGET"
