# VCS Review Flow Examples

## Latest Open GitLab MR

```bash
bash scripts/resolve_review_target.sh --repo /path/to/repo --latest
```

Expected shape:

```text
platform=gitlab
number=42
source_branch=feat/example
head_sha=<sha>
```

## Specific GitHub PR

```bash
bash scripts/resolve_review_target.sh --repo /path/to/repo --number 128
```

## Fetch Review Comments

```bash
bash scripts/fetch_review_comments.sh --repo /path/to/repo --number 128 --platform github --json
```

If `code-review comments` are present, ask the user whether to include code-review comments in scope.

If `discussion comments` are present, ask the user whether to include discussion comments in scope.

Only the approved comment categories move forward.

Resolved code-review feedback is excluded by default.

Outdated threads are validated separately from unresolved threads.

Group approved unresolved and outdated code-review feedback into issue clusters before validation.

For approved comments, dispatch several subagents in parallel to validate whether the comments still make sense.

During that validation, subagents search only within changed files for same-pattern candidates.

Those same-pattern candidates are reported separately from the original issues.

Then confirm the verification report with the user before planning fixes.

## Inspect Repo Policy

```bash
bash scripts/repo_policy.sh --repo /path/to/repo
```

This inspects both `AGENTS.md` and `CLAUDE.md` if they exist. If neither file defines a worktree rule, the fallback is `<repo>/.worktrees`.

## Reuse Existing Worktree

```bash
bash scripts/worktree_sync.sh \
  --repo /path/to/repo \
  --source-branch feat/example \
  --head-sha abcdef1234567890
```

If the worktree already exists and is clean, the script fetches and fast-forwards the source branch, then aligns it to the requested MR/PR head SHA.

## Create Missing Worktree

```bash
bash scripts/worktree_sync.sh \
  --repo /path/to/repo \
  --source-branch feat/example \
  --head-sha abcdef1234567890
```

If the worktree does not exist, the script creates it under the repo-approved worktree root and checks out the remote source branch.

## Comment-Only Proposal

```bash
bash scripts/post_review_comment.sh \
  --repo /path/to/repo \
  --number 42 \
  --body-file /tmp/review-plan.md
```

Suggested comment body structure:

```md
## Change Plan

- Summary of review findings
- Files or subsystems likely to change
- Patch outline
- Verification steps
```

## Installer Dry Run

Codex user-global:

```bash
bash install-skill.sh --agent codex --scope user-global --method symlink --dry-run
```

Claude Code project-local:

```bash
bash install-skill.sh --agent claude --scope project-local --method copy --project-root /path/to/repo --dry-run
```
