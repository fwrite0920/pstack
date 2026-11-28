#!/usr/bin/env bash
# Copy pstack skills into <target>/.agents/skills (WSL2 / Linux / macOS).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PSTACK_SKILLS="$SCRIPT_DIR/skills"
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
    case "$name" in
      .*|*/*) echo "Unknown skill: $name" >&2; exit 1 ;;
    esac
    [ -d "$PSTACK_SKILLS/$name" ] || { echo "Unknown skill: $name" >&2; exit 1; }
    SKILLS+=("$name")
  done
else
  SKILLS=()
  for d in "$PSTACK_SKILLS"/*; do
    [ -d "$d" ] && SKILLS+=("$(basename "$d")")
  done
fi

agents="$TARGET/.agents"
dest="$agents/skills"
marker=.pstack-installed
for directory in "$agents" "$dest"; do
  [ ! -L "$directory" ] || { echo "Destination must be a real directory: $directory" >&2; exit 1; }
done
if [ "$UNLINK" -eq 1 ] && [ ! -d "$dest" ]; then
  echo "$dest => not found, skipped"
  exit 0
fi
mkdir -p -- "$dest"

entry_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

is_pstack_skill() {
  if [ -L "$1" ]; then
    [ "$(readlink "$1")" = "$PSTACK_SKILLS/${1##*/}" ]
  else
    [ -d "$1" ] && [ -f "$1/$marker" ]
  fi
}

lock="$agents/.pstack-sync.lock"
(set -o noclobber; : > "$lock") || exit 1
work=
entry=
cleanup() {
  if [ -n "$work" ]; then
    if [ -n "$entry" ] && entry_exists "$work/previous" && ! entry_exists "$entry"; then
      mv -- "$work/previous" "$entry" || { rm -- "$lock"; return 1; }
    fi
    rm -rf -- "$work"
  fi
  rm -- "$lock"
}
trap cleanup EXIT

if [ "$UNLINK" -eq 1 ]; then
  removed=0
  for entry in "$dest"/*; do
    is_pstack_skill "$entry" || continue
    rm -rf -- "$entry"
    removed=$((removed + 1))
  done
  echo "$dest => removed $removed pstack skill(s)"
else
  work=$(mktemp -d "$agents/.pstack-sync.XXXXXXXX")
  copied=0
  skipped=0
  for name in "${SKILLS[@]}"; do
    entry="$dest/$name"
    if entry_exists "$entry" && ! is_pstack_skill "$entry"; then
      skipped=$((skipped + 1))
      continue
    fi

    # Stage the complete copy before replacing the installed version.
    cp -RL -- "$PSTACK_SKILLS/$name" "$work/next"
    : > "$work/next/$marker"
    if entry_exists "$entry"; then
      mv -- "$entry" "$work/previous"
    fi
    mv -- "$work/next" "$entry"
    rm -rf -- "$work/previous"
    copied=$((copied + 1))
  done
  echo "$dest => copied $copied skill(s) (skipped $skipped project skill(s))"
fi
