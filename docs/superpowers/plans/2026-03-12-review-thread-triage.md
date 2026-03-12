# Review Thread Triage Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add authoritative review-thread state triage, issue clustering, and bounded same-pattern validation to the review-flow stage so resolved code-review feedback is excluded and fix planning is driven by validated issue clusters.

**Architecture:** Extend comment intake to normalize thread-aware review state from GitHub and GitLab, then add a separate clustering and validation layer that excludes resolved threads, groups approved feedback into issue clusters, dispatches a bounded number of subagents, and synthesizes a verification report before fix planning. Keep similar-issue exploration constrained to MR/PR changed files only.

**Tech Stack:** Bash, `jq`, `gh`, `glab`, GraphQL for GitHub review threads

---

## Chunk 1: Thread-State Intake

### Task 1: Add failing tests for authoritative GitHub thread-state intake

**Files:**
- Modify: `tests/test_fetch_review_comments.sh`
- Modify: `scripts/fetch_review_comments.sh`
- Test: `tests/test_fetch_review_comments.sh`

- [ ] **Step 1: Write the failing test**

Extend the GitHub test fixture to include review-thread state from GraphQL with at least one `resolved`, one `unresolved`, and one `outdated` thread.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: FAIL because the current GitHub intake does not fetch or normalize thread state.

- [ ] **Step 3: Write minimal implementation**

Update `scripts/fetch_review_comments.sh` to fetch GitHub review-thread state via GraphQL and include normalized thread-state fields in the JSON output.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: PASS for the GitHub thread-state assertions.

### Task 2: Add failing tests for GitLab resolved-state intake

**Files:**
- Modify: `tests/test_fetch_review_comments.sh`
- Modify: `scripts/fetch_review_comments.sh`
- Test: `tests/test_fetch_review_comments.sh`

- [ ] **Step 1: Write the failing test**

Extend the GitLab fixture to include both resolved and unresolved discussions, including `resolved_by` and `resolved_at` where available.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: FAIL because the current GitLab normalization does not expose discussion resolution state.

- [ ] **Step 3: Write minimal implementation**

Update `scripts/fetch_review_comments.sh` to normalize GitLab discussion resolution state for code-review feedback.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: PASS for the GitLab resolved-state assertions.

## Chunk 2: Scope Triage And Clustering

### Task 3: Add failing tests for resolved-thread exclusion and issue clustering

**Files:**
- Create: `tests/test_review_issue_clustering.sh`
- Create: `scripts/cluster_review_issues.sh`
- Test: `tests/test_review_issue_clustering.sh`

- [ ] **Step 1: Write the failing test**

Create fixtures that represent approved review threads where 10 comments collapse into 8 issue clusters, with resolved threads excluded before clustering.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_review_issue_clustering.sh`
Expected: FAIL because the clustering helper does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/cluster_review_issues.sh` to:
- accept normalized approved review-thread JSON
- exclude resolved code-review threads
- preserve unresolved and outdated threads
- group them into issue clusters

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_review_issue_clustering.sh`
Expected: PASS for resolved exclusion and issue-cluster count assertions.

### Task 4: Add failing tests for bounded dispatch planning

**Files:**
- Create: `tests/test_review_validation_dispatch.sh`
- Create: `scripts/plan_review_validation_dispatch.sh`
- Test: `tests/test_review_validation_dispatch.sh`

- [ ] **Step 1: Write the failing test**

Add cases covering 1-2, 3-4, 5-6, and 7+ issue clusters and assert the dispatch cap of 4 subagents with roughly even distribution.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_review_validation_dispatch.sh`
Expected: FAIL because the dispatch planner does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/plan_review_validation_dispatch.sh` to map issue-cluster counts to bounded subagent assignments.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_review_validation_dispatch.sh`
Expected: PASS for all dispatch-shape assertions.

## Chunk 3: Same-Pattern Exploration Rules

### Task 5: Add failing tests for changed-files-only same-pattern exploration guidance

**Files:**
- Modify: `SKILL.md`
- Modify: `README.md`
- Modify: `docs/examples.md`
- Modify: `tests/test_fetch_review_comments.sh`
- Test: `tests/test_fetch_review_comments.sh`

- [ ] **Step 1: Write the failing test**

Add documentation assertions that:
- resolved code-review threads are excluded by default
- outdated threads are validated separately from unresolved threads
- subagents search only within changed files for same-pattern candidates
- same-pattern candidates are reported separately from original issues

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: FAIL because the docs do not yet describe the triage and same-pattern boundaries.

- [ ] **Step 3: Write minimal implementation**

Update the skill docs and examples to describe:
- review-thread state triage
- issue-cluster-based validation
- changed-files-only same-pattern exploration
- confirmation of the verification report before fix planning

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: PASS for the documentation assertions.

## Chunk 4: Verification

### Task 6: Final verification

**Files:**
- Test: `tests/test_fetch_review_comments.sh`
- Test: `tests/test_review_issue_clustering.sh`
- Test: `tests/test_review_validation_dispatch.sh`

- [ ] **Step 1: Run the full review-flow verification suite**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: PASS

- [ ] **Step 2: Run the clustering verification suite**

Run: `bash tests/test_review_issue_clustering.sh`
Expected: PASS

- [ ] **Step 3: Run the dispatch verification suite**

Run: `bash tests/test_review_validation_dispatch.sh`
Expected: PASS

- [ ] **Step 4: Inspect repo status**

Run: `git status --short`
Expected: Only the intended scripts, docs, and test files are modified or created.
