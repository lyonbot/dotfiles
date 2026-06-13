#!/usr/bin/env bash
#
# Acknowledge inline review comments by adding a reaction. A reaction marks a
# comment as "handled" — fetch-comments.sh filters out any comment that already
# has one, so reacting is what stops the same feedback resurfacing next round.
#
# Pass the databaseId(s) printed by fetch-comments.sh as
# <inline-comment id="..."> — one or many.
#
# Usage:  ./ack-comment.sh <comment_id> [comment_id ...]
#   EMOJI   reaction content (default +1). One of:
#           +1 -1 laugh confused heart hooray rocket eyes
set -euo pipefail

EMOJI="${EMOJI:-+1}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

if [ "$#" -eq 0 ]; then
  echo "usage: EMOJI=+1 ./ack-comment.sh <comment_id> [comment_id ...]" >&2
  exit 1
fi

for id in "$@"; do
  if gh api --method POST \
      -H "Accept: application/vnd.github+json" \
      "repos/$REPO/pulls/comments/$id/reactions" \
      -f content="$EMOJI" >/dev/null 2>&1; then
    echo "  ✓ reacted :$EMOJI: to comment $id"
  else
    echo "  ✗ failed to react to comment $id (already reacted, or invalid id)" >&2
  fi
done
