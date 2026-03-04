---
name: worktree-dev
description: >
  Sets up an isolated git worktree for feature development. Use when the user
  provides a feature name and wants to start work in a new branch — Claude
  generates a slug-style branch name, then runs the setup script to create the
  worktree, install dependencies, and symlink .env. Trigger phrases: "new
  feature worktree", "start feature branch", "create worktree for X",
  "worktree setup", "spin up branch for X".
---

# Worktree Dev

## Workflow

### 1. Generate branch name

Convert the user's feature description into a slug:
- Lowercase, words separated by hyphens
- Remove articles and filler words (a, the, for, to, …)
- Keep it short (≤ 5 words)
- Prefix with `feat/` unless the user specifies otherwise (use `fix/` for bugs, `chore/` for maintenance)

Examples:
| Input | Branch |
|---|---|
| "user authentication with OAuth" | `feat/user-auth-oauth` |
| "fix the login redirect bug" | `fix/login-redirect` |
| "add dark mode toggle" | `feat/dark-mode-toggle` |

Show the proposed branch name to the user and confirm before proceeding.

### 2. Run setup script

From the **repo root**, run:

```bash
bash /Users/yon/.claude/my-skills/worktree-dev/scripts/setup_worktree.sh <branch-name>
```

The script will:
1. Create `<repo-root>/.worktree/<branch-name>` via `git worktree add`
2. Detect the package manager from the lockfile and run install
3. Search for `.env` and `.env.*` files at the repo root and symlink any found into the worktree
4. Print `Branch <name> okay under <path>`

Supported package managers (auto-detected by lockfile):
| Lockfile | Command |
|---|---|
| `pnpm-lock.yaml` | `pnpm install` |
| `yarn.lock` | `yarn install` |
| `package-lock.json` | `npm install` |
| `Pipfile.lock` | `pipenv install` |
| `poetry.lock` | `poetry install` |
| `requirements.txt` | `pip install -r requirements.txt` |

### 3. Report to user

After success, tell the user:
- The branch name and worktree path
- Which package manager was used (or if install was skipped)
- Whether `.env` was linked
- Remind them to add `.worktree/` to `.gitignore` if not already present

## Notes

- Must be run from inside a git repository; fail with a clear error if not.
- If the branch already exists, the script checks it out instead of creating a new one.
- The `.worktree/` directory should be in `.gitignore` — mention this to the user.
