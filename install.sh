#!/usr/bin/env bash
# Symlink every skill in this repo into Claude Code's user-level skills directory,
# making them available in every workspace on this machine.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${HOME}/.claude/skills"

mkdir -p "$DEST_DIR"

for skill in "$SRC_DIR"/*/; do
  name="$(basename "$skill")"
  [ "$name" = ".git" ] && continue
  [ -f "$skill/SKILL.md" ] || continue

  target="$DEST_DIR/$name"

  if [ -L "$target" ]; then
    rm "$target"
  elif [ -e "$target" ]; then
    echo "skip  $name — $target exists and is not a symlink; remove it first" >&2
    continue
  fi

  ln -s "${skill%/}" "$target"
  echo "link  $name -> $target"
done

echo
echo "Done. Skills are available in every workspace."
echo "Update later with: git -C '$SRC_DIR' pull"
