#!/usr/bin/env bash
# Link (or unlink) pstack skills into a specific project directory (for WSL2 / Linux / macOS).
# Links into <target>/.agents/skills (Antigravity, Codex, OMP, OpenCode) and <target>/.pi/skills (Pi).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PSTACK_SKILLS="$SCRIPT_DIR/skills"
TOOLS=(".agents/skills" ".pi/skills")
UNLINK=0
ONLY=""
TARGET=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--unlink] [--only s1,s2,...] <project-dir>

Examples:
  $(basename "$0") ~/work/my-app
  $(basename "$0") --only architect,blast-radius,interrogate ~/work/my-app
  $(basename "$0") --unlink ~/work/my-app
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --unlink|-u) UNLINK=1; shift ;;
    --only|-o) ONLY="${2:-}"; shift 2 ;;
    --help|-h) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) TARGET="$1"; shift ;;
  esac
done

[ -n "$TARGET" ] || usage
[ -d "$TARGET" ] || { echo "Target directory does not exist: $TARGET" >&2; exit 1; }
TARGET=$(cd "$TARGET" && pwd)

if [ -n "$ONLY" ]; then
  IFS=',' read -r -a WANTED <<< "$ONLY"
  SKILLS=()
  for name in "${WANTED[@]}"; do
    name=$(echo "$name" | xargs)
    [ -n "$name" ] || continue
    [ -d "$PSTACK_SKILLS/$name" ] || { echo "Unknown skill: $name" >&2; exit 1; }
    SKILLS+=("$name")
  done
else
  SKILLS=()
  for d in "$PSTACK_SKILLS"/*; do
    [ -d "$d" ] && SKILLS+=("$(basename "$d")")
  done
fi

for rel in "${TOOLS[@]}"; do
  dest="$TARGET/$rel"
  if [ "$UNLINK" -eq 1 ]; then
    [ -d "$dest" ] || { echo "$dest => not found, skipped"; continue; }
    removed=0
    for entry in "$dest"/*; do
      [ -L "$entry" ] || continue
      link_target=$(readlink "$entry" || true)
      case "$link_target" in
        "$PSTACK_SKILLS"/*)
          rm "$entry"
          removed=$((removed + 1))
          ;;
      esac
    done
    echo "$dest => unlinked $removed pstack skill(s)"
  else
    mkdir -p "$dest"
    added=0
    skipped=0
    for name in "${SKILLS[@]}"; do
      if [ -e "$dest/$name" ] || [ -L "$dest/$name" ]; then
        skipped=$((skipped + 1))
      else
        ln -s "$PSTACK_SKILLS/$name" "$dest/$name"
        added=$((added + 1))
      fi
    done
    echo "$dest => linked $added skill(s) (skipped $skipped existing)"
  fi
done
