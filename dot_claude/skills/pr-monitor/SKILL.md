---
name: pr-monitor
description: >
  Watches the current branch's open GitHub PR for new reviewer comments and CI
  failures, then autonomously fixes issues, runs tests, and pushes.
  Trigger phrases: "monitor my PR", "watch PR for feedback", "poll PR comments",
  "keep an eye on my PR", "auto-fix PR issues", "fix and push when CI fails".
---

# PR Monitor

On startup, immediately reacts to current PR state. Delegates polling to a
background subagent so the main agent stays free to respond to the user.

## Prerequisites

- `gh` CLI authenticated (`gh auth status`)
- `jq` installed
- Current directory is the git repo root

## Roles

| Agent | Responsibility |
|---|---|
| **Main agent** | Initial check, fix workflow, user communication |
| **Poller subagent** (Bash, background) | Periodic snapshots, change detection, signal main agent |
| **Haiku subagent** (on-demand) | Semantic classification of comment intent |

---

## Workflow

### 1. Initial check (main agent, on startup)

Generate a random session ID once on startup (e.g. `RID=$RANDOM`) and use it
in all temp file names for this session to avoid conflicts with concurrent runs.

Run `poll_pr.sh` immediately → `/tmp/pr_snapshot_prev_$RID.json`.

- If actionable (see criteria below) → run **Fix workflow** (Step 3)
- Then → run **Poll decision** (Step 2)

### 2. Poll decision (main agent)

After startup and after every fix attempt, evaluate whether polling is needed.

**CI still running?** (deterministic — check snapshot JSON)
- Any check has `status: in_progress` or `status: queued`

**Reviewer still evaluating?** (semantic — launch Haiku subagent)
- Pass all comment bodies to a `model: haiku` Task subagent
- Prompt: _"Do any of these comments indicate a reviewer has not yet reached a
  final verdict (e.g. still looking, will check, taking another pass)?
  Reply YES or NO only."_

**If BOTH are false** → report final state to user and stop. Do not launch poller.

**If EITHER is true** → launch the **Poller subagent** (Step 4) and wait for
it to signal back.

### 3. Fix workflow (main agent)

Triggered by initial check or poller signal:

1. **Read** recent comments — understand requested changes / bugs reported
2. **Read** CI failure logs:
   ```bash
   gh run list --branch <branch> --limit 1
   gh run view <run-id> --log-failed
   ```
3. **Diagnose** — identify files to change
4. **Fix** — apply code edits
5. **Test** — discover and run the project test command:
   `package.json` → `npm test` · `Makefile` → `make test` ·
   `pyproject.toml` → `pytest` · `Cargo.toml` → `cargo test`
6. **Push** — only if tests pass:
   ```bash
   git add -A && git commit -m "fix: address PR feedback / CI failures" && git push
   ```
7. **Report** — summarise what was fixed to the user
8. **Re-evaluate** — return to Step 2

### 4. Poller subagent (Bash, run_in_background=true)

Launch once when polling is needed. It loops until it detects a change, then
writes a signal file and exits — main agent picks it up.

```
SKILL_DIR=<path to skill scripts>
RID=<session random ID passed from main agent>
PREV=/tmp/pr_snapshot_prev_$RID.json
NEW=/tmp/pr_snapshot_new_$RID.json
SIGNAL=/tmp/pr_needs_action_$RID

while true; do
  sleep 60
  bash "$SKILL_DIR/poll_pr.sh" > "$NEW"

  # Check PR state
  STATE=$(jq -r '.state // "open"' "$NEW")
  if [[ "$STATE" == "MERGED" || "$STATE" == "CLOSED" ]]; then
    echo "closed" > "$SIGNAL"; exit 0
  fi

  # Fingerprint comparison
  fp_new=$(jq -r '[.comments[].id, .comments[].updated_at,
    (.ci[]|select(.conclusion=="failure" or .conclusion=="timed_out")|.name)]
    | join(",")' "$NEW")
  fp_prev=$(jq -r '[.comments[].id, .comments[].updated_at,
    (.ci[]|select(.conclusion=="failure" or .conclusion=="timed_out")|.name)]
    | join(",")' "$PREV" 2>/dev/null || echo "")

  if [[ "$fp_new" != "$fp_prev" ]]; then
    cp "$NEW" "$PREV"
    echo "changed" > "$SIGNAL"; exit 0
  fi

  cp "$NEW" "$PREV"
done
```

Main agent checks `/tmp/pr_needs_action_$RID` periodically (e.g. via `TaskOutput`).
On signal:
- `changed` → run Fix workflow, then re-evaluate polling
- `closed` → report to user and stop

### 5. Stop conditions

- Signal file contains `closed` (PR merged or closed)
- Poll decision returns BOTH false (CI settled, reviewer done)
- Three consecutive fix attempts fail to make CI green
- User sends any message

---

## Snapshot format

```json
{
  "pr_number": 42,
  "repo": "owner/repo",
  "sha": "abc123",
  "comments": [{"id":1,"author":"reviewer","body":"...","updated_at":"..."}],
  "inline_comments": [{"id":2,"author":"reviewer","path":"src/foo.ts","line":10,"body":"...","updated_at":"..."}],
  "ci": [{"name":"test","status":"completed","conclusion":"failure"}]
}
```

## Actionable criteria

A snapshot is actionable when ANY of:
- Any comment exists (on first run)
- Any CI check has `conclusion: failure` or `conclusion: timed_out`
- Fingerprint differs from previous snapshot
