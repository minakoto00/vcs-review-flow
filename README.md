# VCS Review Flow

`vcs-review-flow` is a reusable skill for pulling the latest open GitLab merge request or GitHub pull request into a local worktree, reviewing it, producing a change plan, and then either implementing the fixes or posting the proposal back to the remote.

It is built for repos that use repo-level instructions such as `AGENTS.md` or `CLAUDE.md` to control where worktrees should live.

## What It Does

- resolves the latest open MR/PR, or a user-specified MR/PR number
- fetches MR/PR review feedback and splits it into `code-review comments` and `discussion comments`
- detects GitHub vs GitLab from the repo remote
- inspects `AGENTS.md` and `CLAUDE.md` before any worktree action
- reuses or creates the correct local worktree for the MR/PR source branch
- syncs the worktree to the remote branch head
- supports a review flow that ends with a change plan and explicit finish options
- can post proposed changes back as a GitLab/GitHub comment instead of implementing locally

## Prerequisites

- `git`
- `jq`
- `gh` for GitHub repositories
- `glab` for GitLab repositories

## Installation

Run installation commands from the skill directory:

```bash
cd /path/to/vcs-review-flow
```

Run the interactive installer:

```bash
bash ./install-skill.sh
```

The installer will ask for:
- target agent: Codex or Claude Code
- install scope: user-global or project-local
- install method: symlink or copy

### Non-Interactive Installation Commands

Codex, user-global, symlink:

```bash
bash ./install-skill.sh \
  --agent codex \
  --scope user-global \
  --method symlink
```

Codex, project-local, copy:

```bash
bash ./install-skill.sh \
  --agent codex \
  --scope project-local \
  --method copy \
  --project-root /path/to/repo
```

Claude Code, user-global, symlink:

```bash
bash ./install-skill.sh \
  --agent claude \
  --scope user-global \
  --method symlink
```

Claude Code, project-local, copy:

```bash
bash ./install-skill.sh \
  --agent claude \
  --scope project-local \
  --method copy \
  --project-root /path/to/repo
```

Dry run without installing:

```bash
bash ./install-skill.sh \
  --agent codex \
  --scope user-global \
  --method symlink \
  --dry-run
```

## Usage

From a repository you want to review, the core steps are:

1. Detect the platform.
2. Resolve the latest open MR/PR or a specific one.
3. Fetch comment summaries for the MR/PR.
4. Inspect repo policy from `AGENTS.md` and `CLAUDE.md`.
5. Ask the user whether to include code-review comments in scope.
6. Ask the user whether to include discussion comments in scope.
7. Reuse or create the source-branch worktree.
8. Run review in that worktree.
9. Produce a change plan.
10. Choose whether to implement locally or post the proposal remotely.

### Detect Platform

```bash
bash ./scripts/detect_platform.sh \
  --repo /path/to/repo
```

### Resolve the Latest Open MR/PR

```bash
bash ./scripts/resolve_review_target.sh \
  --repo /path/to/repo \
  --latest
```

### Resolve a Specific MR/PR Number

```bash
bash ./scripts/resolve_review_target.sh \
  --repo /path/to/repo \
  --number 123
```

### Inspect Repo Worktree Policy

```bash
bash ./scripts/repo_policy.sh \
  --repo /path/to/repo
```

### Fetch Review Comments

```bash
bash ./scripts/fetch_review_comments.sh \
  --repo /path/to/repo \
  --number 123 \
  --platform github \
  --json
```

If comments are present:
- Ask the user whether to include code-review comments in scope.
- Ask the user whether to include discussion comments in scope.
- Pull only the approved comment categories into the review context.
- Preserve richer remote metadata for approved code-review comments.
- Resolved code-review feedback is excluded by default.
- Outdated threads are validated separately from unresolved threads.
- Group approved unresolved and outdated code-review feedback into issue clusters before validation.
- If any categories are approved, dispatch several subagents in parallel to validate those approved comments.
- Search only within changed files for same-pattern candidates.
- Report same-pattern candidates separately from the original issues.
- Show a simple verification report.
- Ask the user to confirm the verification report before planning fixes.
- If the user confirms, keep the confirmed issues in scope even when tests do not yet cover them.

### Prepare or Reuse the Worktree

```bash
bash ./scripts/worktree_sync.sh \
  --repo /path/to/repo \
  --source-branch feat/example \
  --head-sha abcdef1234567890
```

### Post a Comment-Only Proposal

```bash
bash ./scripts/post_review_comment.sh \
  --repo /path/to/repo \
  --number 123 \
  --body-file /tmp/review-plan.md
```

## Safety Rules

- The skill reads both `AGENTS.md` and `CLAUDE.md` when present.
- If those files conflict on worktree policy, it stops instead of guessing.
- If an existing worktree is dirty, it stops before syncing.
- It does not force-push unless the user explicitly asks.
- It requires `gh` or `glab` authentication for live remote operations.

## Files

- `SKILL.md`: skill entrypoint and workflow contract
- `install-skill.sh`: interactive and scripted installer
- `scripts/`: helper scripts for platform detection, target resolution, policy parsing, worktree sync, and comment posting
- `scripts/fetch_review_comments.sh`: helper for normalized MR/PR comment intake
- `docs/examples.md`: extra examples

## Related Docs

- `SKILL.md`
- `docs/examples.md`
