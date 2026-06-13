#!/usr/bin/env bash
#
# Fetch actionable review feedback for the current branch's PR:
#   1. The last 5 conversation (issue) comments.
#   2. Inline code-review comments that are NOT outdated and have NO reaction
#      (and live on an unresolved thread).
#
# Outdated detection: GraphQL `comment.outdated` is authoritative — it flips
# true once the diff hunk the comment anchored to has changed (equivalent to
# the REST `line == null` signal). A reaction on a comment is treated as
# "already acknowledged" and filtered out.
#
# Usage: ./fetch-comments.sh [PR_NUMBER]
#   PR_NUMBER defaults to the PR of the current branch.
#
set -euo pipefail

PR="${1:-$(gh pr view --json number -q .number)}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
OWNER="${REPO%/*}"
NAME="${REPO#*/}"
COUNT=5

echo "════════ PR #$PR · last $COUNT conversation comments ════════"
gh api "repos/$REPO/issues/$PR/comments" --paginate \
  --jq 'sort_by(.created_at) | .[-'"${COUNT}"':] | reverse | .[]
        | "<comment author=\"\(.user.login)\" created=\"\(.created_at)\">\n\(.body)\n</comment>"'

echo
echo "════════ inline comments: NOT outdated, NO reaction, NOT resolved ════════"
gh api graphql -f query='
query($owner:String!,$name:String!,$num:Int!){
  repository(owner:$owner,name:$name){
    pullRequest(number:$num){
      reviewThreads(first:100){ nodes{
        isResolved
        comments(first:100){ nodes{
          databaseId
          author{login}
          outdated
          reactions{totalCount}
          path
          line
          bodyText
        }}
      }}
    }
  }
}' -f owner="$OWNER" -f name="$NAME" -F num="$PR" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[]
         | select(.isResolved | not)
         | .comments.nodes[]
         | select(.outdated == false and .reactions.totalCount == 0)
         | "<inline-comment id=\"\(.databaseId)\" author=\"\(.author.login)\" path=\"\(.path):\(.line)\">\n\(.bodyText)\n</inline-comment>"]
        | if length == 0
          then "(none — all inline comments are outdated, resolved, or already reacted to)"
          else .[] end'
