#!/usr/bin/env bash
# Usage: setup_worktree.sh <branch-name>
# Run from the repo root. Creates a worktree, installs deps, and links .env.

set -euo pipefail

BRANCH="${1:?Usage: setup_worktree.sh <branch-name>}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREE_DIR="$REPO_ROOT/.worktree/$BRANCH"

# 1. Create the worktree (create branch if it doesn't exist)
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git worktree add "$WORKTREE_DIR" "$BRANCH"
else
  git worktree add -b "$BRANCH" "$WORKTREE_DIR"
fi

# 2. Install dependencies
cd "$WORKTREE_DIR"

if [ -f "pnpm-lock.yaml" ]; then
  echo "Detected pnpm — running pnpm install"
  pnpm install
elif [ -f "yarn.lock" ]; then
  echo "Detected yarn — running yarn install"
  yarn install
elif [ -f "package-lock.json" ]; then
  echo "Detected npm — running npm install"
  npm install
elif [ -f "Pipfile.lock" ]; then
  echo "Detected pipenv — running pipenv install"
  pipenv install
elif [ -f "poetry.lock" ]; then
  echo "Detected poetry — running poetry install"
  poetry install
elif [ -f "requirements.txt" ]; then
  echo "Detected requirements.txt — running pip install"
  pip install -r requirements.txt
else
  echo "No known lockfile detected — skipping install"
fi

# 3. Find and symlink all .env* files from repo root
ENV_COUNT=0
for ENV_FILE in "$REPO_ROOT"/.env "$REPO_ROOT"/.env.*; do
  # Skip glob patterns that didn't expand (no match)
  [ -f "$ENV_FILE" ] || continue
  BASENAME="$(basename "$ENV_FILE")"
  ln -sf "$ENV_FILE" "$WORKTREE_DIR/$BASENAME"
  echo "Linked $BASENAME"
  ENV_COUNT=$((ENV_COUNT + 1))
done

if [ "$ENV_COUNT" -eq 0 ]; then
  echo "No .env files found at repo root — skipping symlink"
fi

# 4. Done
echo ""
echo "Branch $BRANCH okay under $WORKTREE_DIR"
