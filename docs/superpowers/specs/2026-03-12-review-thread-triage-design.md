---
title: Review Thread Triage Design
date: 2026-03-12
---

# Review Thread Triage Design

## Goal

Improve the review-flow stage of `vcs-review-flow` so code-review feedback is triaged by thread state, resolved feedback is excluded from scope, similar issues can be found within changed files, and subagent work is dispatched by issue cluster rather than raw comment count.

## Scope

This design covers only the review-flow stage.

It does not cover:
- README packaging simplification
- installer fixes
- `npx` publishing and update flow

Those belong to a separate stage.

## Current State

- `scripts/fetch_review_comments.sh` normalizes GitHub pull-request review comments and GitLab MR discussions into `code_review_comments` and `discussion_comments`.
- The current flow preserves richer remote metadata for code-review comments, but it does not know whether a review thread is resolved or outdated.
- The current workflow treats approved comments as flat items, not as grouped issues or threads.
- The current guidance tells subagents to validate comments, but it does not tell them to search for similar issues within changed files.

## Constraints

- Resolved code-review feedback must be excluded from review scope by default.
- Outdated code-review feedback must not be treated as identical to unresolved feedback.
- Similar-issue exploration must be limited to files changed by the MR/PR.
- Subagent fan-out must be bounded and based on issue clusters, not comment count.
- Discussion comments remain a separate scope choice and do not participate in review-thread state triage for now.

## Design

### Review Unit

The review-flow should treat code-review feedback as review threads or discussions, not as isolated comments.

For GitHub:
- use GraphQL review-thread data as the authoritative source for thread state
- keep REST review-comment data only for comment-level file and line metadata when needed
- preserve thread-level state such as whether the thread is resolved or outdated

For GitLab:
- use MR discussions as the primary source
- preserve discussion resolution state and reviewer metadata directly from the MR discussions API

### Thread State Model

Approved code-review feedback is partitioned into three buckets:

- `resolved`
- `unresolved`
- `outdated`

Rules:
- `resolved` threads are excluded from active review scope by default
- `unresolved` threads enter validation
- `outdated` threads also enter validation, but as possible still-relevant issues rather than automatic in-scope findings

The user still makes the initial choice about whether `code-review comments` are in scope at all. If the user declines them, no thread-state triage is needed.

### Issue Clustering

The flow should not dispatch subagents per comment or per thread.

Instead, after user approval and thread-state filtering:
- group selected review threads into issue clusters
- cluster by likely root cause or same requested change
- keep unrelated issue types separate even if they touch the same file
- allow a single thread to remain a singleton cluster if it is unique

This creates an `issue set` that becomes the dispatch unit for subagents.

### Subagent Dispatch Strategy

Use a bounded dispatch strategy based on issue-cluster count:

- 1 to 2 issue clusters: 1 subagent
- 3 to 4 issue clusters: 2 subagents
- 5 to 6 issue clusters: 3 subagents
- 7 or more issue clusters: 4 subagents maximum, with clusters distributed evenly

Target about two issue clusters per subagent.

Each subagent receives:
- assigned issue clusters
- the normalized thread/comment payload for those clusters
- the MR/PR changed-file list
- the prepared review workspace context

Each subagent must:
- validate whether each assigned issue cluster still makes sense
- classify each cluster as `likely_valid`, `unclear`, or `likely_stale`
- search only within changed files for same-pattern candidates
- report same-pattern candidates separately from the original issue clusters

### Similar-Issue Exploration

Same-pattern exploration is an explicit second pass, not an implicit scope expansion.

Rules:
- search only within MR/PR changed files
- do not search the surrounding repository outside the diff for this stage
- report each same-pattern finding as a candidate, not as an automatically confirmed issue
- include short evidence for why it appears to be the same class of problem

This keeps the flow focused and prevents comment-driven review from turning into uncontrolled cleanup.

### Synthesis And Verification Report

After subagent responses return, the controller performs a synthesis pass to:
- deduplicate overlapping same-pattern candidates
- combine duplicate judgments across threads in the same cluster
- separate results into:
  - excluded resolved threads
  - validated unresolved or outdated issue clusters
  - unclear or likely stale issue clusters
  - same-pattern candidates in changed files

The user-facing verification report must show:
- what was excluded as resolved
- what looks valid and worth fixing
- what remains unclear or likely stale
- what same-pattern candidates were found in changed files

The user confirms this verification report before any fix plan is produced.

### Fix Planning Rule

After user confirmation:
- confirmed issue clusters are in scope
- confirmed same-pattern candidates are also in scope
- lack of existing tests does not remove a confirmed issue from scope

Tests still matter during implementation, but they are not the gate for whether a confirmed issue belongs in the fix plan.

## Platform Details

### GitHub

Use GraphQL review-thread data to fetch authoritative thread state, including:
- resolved state
- outdated state
- thread identity and associated comments

Use existing REST review-comment intake only as supplemental file and line metadata where useful.

### GitLab

Use MR discussions and note resolution fields, including:
- `resolved`
- `resolved_by`
- `resolved_at`

These are sufficient for authoritative resolved-state filtering on GitLab.

## Testing

Add or extend shell-based fixtures to cover:

- GitHub review threads with `resolved`, `unresolved`, and `outdated` states
- GitLab discussions with resolved and unresolved states
- exclusion of resolved review threads from active validation scope
- issue clustering from multiple comments into fewer issue clusters
- bounded dispatch strategy for clustered issues
- same-pattern candidate reporting limited to changed files
- docs updates describing resolved filtering and same-pattern exploration boundaries
