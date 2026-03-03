#!/usr/bin/env bash
# poll_pr.sh — emit a JSON snapshot of PR state: last 5 comments + all inline review comments + CI status
# Usage: poll_pr.sh [pr_number]   (auto-detects from current branch if omitted)
# Output: single JSON object to stdout; exits non-zero on error

set -euo pipefail

# ── resolve PR number ────────────────────────────────────────────────────────
if [[ $# -ge 1 ]]; then
  PR_NUMBER="$1"
else
  PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null) || {
    echo '{"error":"no open PR for current branch"}' >&2; exit 1
  }
fi

REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

# ── last 5 issue-level comments (newest-first) ───────────────────────────────
COMMENTS=$(gh api "repos/$REPO/issues/$PR_NUMBER/comments" \
  --jq '[.[] | {id:.id, author:.user.login, body:.body, updated_at:.updated_at}] | reverse | .[0:5]')

# ── ALL inline review comments (pull request review comments) ─────────────────
INLINE_COMMENTS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/comments" \
  --jq '[.[] | {id:.id, author:.user.login, path:.path, line:.line, body:.body, updated_at:.updated_at}]')

# ── CI / check-runs status ───────────────────────────────────────────────────
HEAD_SHA=$(gh pr view "$PR_NUMBER" --json headRefOid -q '.headRefOid')

CI_SUMMARY=$(gh api "repos/$REPO/commits/$HEAD_SHA/check-runs" \
  --jq '.check_runs | map({name:.name, status:.status, conclusion:.conclusion}) | unique_by(.name)')

# ── assemble output ──────────────────────────────────────────────────────────
jq -n \
  --argjson pr_number      "$PR_NUMBER" \
  --arg     repo           "$REPO" \
  --arg     sha            "$HEAD_SHA" \
  --argjson comments       "$COMMENTS" \
  --argjson inline_comments "$INLINE_COMMENTS" \
  --argjson ci             "$CI_SUMMARY" \
  '{pr_number:$pr_number, repo:$repo, sha:$sha, comments:$comments, inline_comments:$inline_comments, ci:$ci}'
