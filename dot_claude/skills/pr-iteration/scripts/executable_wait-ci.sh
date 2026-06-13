#!/usr/bin/env bash
#
# Wait for the current branch's PR CI to make progress, and classify each
# check as BLOCKING (required to merge) vs ADVISORY (non-blocking — finds
# issues but won't gate the merge, e.g. code-review / security-review /
# "Agent Behavior Detection").
#
# Why the split matters: an advisory check can report conclusion=failure
# without blocking anything; its findings come back as PR comments, not as a
# merge gate. Treating that as a hard CI failure would send you chasing green
# on a check that was never going to block. The authoritative per-PR signal is
# GraphQL `isRequired(pullRequestNumber:)` — NOT the ruleset context list,
# which under-reports.
#
# Blocks until EITHER:
#   * running checks reach 0 (everything finished), OR
#   * running checks drop by >= PROGRESS_DROP (default 3) from the baseline
#     captured on the first poll — i.e. N2 <= N - 3.
# For the pr-iteration loop you want full settle, so call with PROGRESS_DROP=999.
#
# Classification per check:
#   running — CheckRun.status != COMPLETED, or StatusContext.state PENDING/
#             EXPECTED, or completed with no conclusion yet.
#   passed  — conclusion in SUCCESS/NEUTRAL/SKIPPED/STALE, or state SUCCESS.
#   failed  — anything else; further tagged [required] or [advisory].
#
# Each poll prints the running/passed/failed tally (failed split into
# blocking/advisory) and lists failed checks with name + runId + jobId so you
# can drill in via:
#   gh run view <runId> --log-failed
#   gh run view --job <jobId> --log-failed
#
# Usage: ./wait-ci.sh [PR_NUMBER]
#   PR_NUMBER       defaults to the PR of the current branch.
# Env:
#   POLL_INTERVAL   seconds between polls           (default 30)
#   PROGRESS_DROP   how many must finish to unblock (default 3; 999 = full settle)
#   MAX_WAIT        hard cap in seconds, 0 = none   (default 3600)
#
# Exit codes: 0 unblocked / all done · 1 timed out · 2 no checks found.
set -euo pipefail

PR="${1:-$(gh pr view --json number -q .number)}"
POLL_INTERVAL="${POLL_INTERVAL:-30}"
PROGRESS_DROP="${PROGRESS_DROP:-3}"
MAX_WAIT="${MAX_WAIT:-3600}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
OWNER="${REPO%/*}"
NAME="${REPO#*/}"

# GraphQL: per-check status/conclusion + isRequired (the real blocking signal).
read -r -d '' GQL <<'GQLEOF' || true
query($o:String!,$n:String!,$p:Int!){
  repository(owner:$o,name:$n){ pullRequest(number:$p){
    commits(last:1){ nodes{ commit{ statusCheckRollup{ contexts(first:100){ nodes{
      __typename
      ... on CheckRun   { name    status conclusion isRequired(pullRequestNumber:$p) detailsUrl }
      ... on StatusContext { context state          isRequired(pullRequestNumber:$p) targetUrl  }
    }}}}}}
  }}
}
GQLEOF

# jq: one TSV row per check — category<TAB>required<TAB>name<TAB>runId<TAB>jobId<TAB>url
read -r -d '' JQ <<'JQEOF' || true
def cat:
  if .__typename == "CheckRun" then
    (.status // "" | ascii_upcase) as $s
    | (.conclusion // "" | ascii_upcase) as $c
    | if $s != "COMPLETED" or $c == "" then "running"
      elif ($c|IN("SUCCESS","NEUTRAL","SKIPPED","STALE")) then "passed"
      else "failed" end
  else
    (.state // "" | ascii_upcase) as $st
    | if ($st|IN("PENDING","EXPECTED")) then "running"
      elif $st == "SUCCESS" then "passed"
      else "failed" end
  end;
(.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.nodes // [])[]
| cat as $c
| (if .isRequired then "required" else "advisory" end) as $req
| (.detailsUrl // .targetUrl // "") as $u
| ((($u | capture("runs/(?<r>[0-9]+)")?) // {}).r // "") as $run
| ((($u | capture("/job/(?<j>[0-9]+)")?) // {}).j // "") as $job
| [$c, $req, (.name // .context // "?"), $run, $job, $u]
| @tsv
JQEOF

baseline=""
start=$(date +%s)

while :; do
  ts="$(date +%H:%M:%S)"
  json="$(gh api graphql -f query="$GQL" -f o="$OWNER" -f n="$NAME" -F p="$PR" 2>/dev/null || echo '{}')"
  tsv="$(printf '%s' "$json" | jq -r "$JQ" 2>/dev/null || true)"

  if [ -z "$tsv" ]; then
    echo "[$ts] PR #$PR — no checks found yet."
    [ -z "$baseline" ] && { sleep "$POLL_INTERVAL"; continue; }
  fi

  running=$(printf '%s\n' "$tsv" | grep -c '^running' || true)
  passed=$(printf  '%s\n' "$tsv" | grep -c '^passed'  || true)
  failed=$(printf  '%s\n' "$tsv" | grep -c '^failed'  || true)
  block=$(printf   '%s\n' "$tsv" | grep -c '^failed	required' || true)
  advis=$(printf   '%s\n' "$tsv" | grep -c '^failed	advisory' || true)

  [ -z "$baseline" ] && baseline="$running"

  echo "════════ [$ts] PR #$PR · running=$running passed=$passed failed=$failed (blocking=$block advisory=$advis · baseline running=$baseline) ════════"

  if [ "$block" -gt 0 ]; then
    echo "── ✗ BLOCKING failures (required — must fix to merge) ──"
    printf '%s\n' "$tsv" | awk -F'\t' '
      $1=="failed" && $2=="required" { printf "  ✗ %-45s run=%s job=%s\n", $3, ($4==""?"-":$4), ($5==""?"-":$5) }'
  fi
  if [ "$advis" -gt 0 ]; then
    echo "── ⚠ advisory failures (non-blocking — findings arrive as PR comments) ──"
    printf '%s\n' "$tsv" | awk -F'\t' '
      $1=="failed" && $2=="advisory" { printf "  ⚠ %-45s run=%s job=%s\n", $3, ($4==""?"-":$4), ($5==""?"-":$5) }'
  fi

  # Stop: everything done, or enough checks finished to count as progress.
  if [ "$running" -eq 0 ]; then
    echo "✓ all checks settled (running=0)."
    exit 0
  fi
  if [ "$running" -le $((baseline - PROGRESS_DROP)) ]; then
    echo "✓ progress: running dropped from $baseline to $running (>= $PROGRESS_DROP finished)."
    exit 0
  fi

  if [ "$MAX_WAIT" -gt 0 ]; then
    elapsed=$(( $(date +%s) - start ))
    if [ "$elapsed" -ge "$MAX_WAIT" ]; then
      echo "✗ timed out after ${elapsed}s (running=$running)."
      exit 1
    fi
  fi

  sleep "$POLL_INTERVAL"
done
