#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree has uncommitted changes. Commit or stash them before syncing." >&2
  exit 1
fi

echo "==> Fetching upstream..."
git fetch upstream

echo "==> Rebasing local commits onto upstream/main..."
git rebase upstream/main

echo "==> Pushing to origin/main..."
git push --force-with-lease origin main

echo "==> Done! Synced with upstream/main."
