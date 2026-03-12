# Review PR Additional Review Decision Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require `review-pr` to ask an explicit three-option question about running a full changeset review for additional issues after remote comment handling, and prevent the workflow from ending at comment verification alone.

**Architecture:** This change is documentation-first because the behavior is defined by the packaged skill contract. Update the workflow description in the main skill entrypoint, mirror that contract in the packaged README and examples, and lock the behavior in with shell assertions that require the decision point and exact option text.

**Tech Stack:** Markdown skill docs, mermaid flowchart, shell test suite (`bash`, `rg`, `grep`)

---

## Chunk 1: Update Skill Contract

### Task 1: Tighten `SKILL.md` workflow ordering

**Files:**
- Modify: `skills/review-pr/SKILL.md`
- Test: `tests/test_fetch_review_comments.sh`

- [ ] **Step 1: Write the failing test**

Add assertions to `tests/test_fetch_review_comments.sh` requiring `skills/review-pr/SKILL.md` to mention the mandatory additional-review decision and the exact three option labels.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: FAIL because `skills/review-pr/SKILL.md` does not yet include the new wording.

- [ ] **Step 3: Write minimal implementation**

Update `skills/review-pr/SKILL.md` so the workflow explicitly requires:
- a mandatory question after comment handling and before change planning
- the exact options:
  - `Review full changeset for additional issues`
  - `Do not do additional reviews`
  - `Specify otherwise`
- a branch that runs a full code review session when the user chooses option 1

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: PASS for the new `SKILL.md` assertions or progress to the next missing doc file.

- [ ] **Step 5: Commit**

```bash
git add skills/review-pr/SKILL.md tests/test_fetch_review_comments.sh
git commit -m "docs: require additional review decision in review-pr"
```

## Chunk 2: Mirror Contract in Packaged Docs

### Task 2: Update README flow and examples

**Files:**
- Modify: `skills/review-pr/README.md`
- Modify: `skills/review-pr/docs/examples.md`
- Test: `tests/test_fetch_review_comments.sh`

- [ ] **Step 1: Write the failing test**

Extend `tests/test_fetch_review_comments.sh` with assertions for:
- README prose mentioning the mandatory question
- README mermaid flow including the decision before change planning
- examples mentioning the exact three options

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: FAIL because README/examples do not yet mention the decision point and exact options.

- [ ] **Step 3: Write minimal implementation**

Update `skills/review-pr/README.md` and `skills/review-pr/docs/examples.md` so they:
- describe the mandatory additional-review question regardless of comment presence
- include the exact three options
- make clear that change planning happens only after the decision is handled

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/review-pr/README.md skills/review-pr/docs/examples.md tests/test_fetch_review_comments.sh
git commit -m "docs: mirror review-pr additional review decision"
```

## Chunk 3: Final Verification

### Task 3: Validate final state

**Files:**
- Modify: `tests/test_fetch_review_comments.sh` if cleanup is needed

- [ ] **Step 1: Run full verification**

Run: `bash tests/test_fetch_review_comments.sh`
Expected: PASS

- [ ] **Step 2: Inspect diff for scope**

Run: `git diff --stat HEAD~1..HEAD`
Expected: Only `review-pr` docs/tests related to the additional-review decision are included.

- [ ] **Step 3: Commit any remaining cleanup**

```bash
git add tests/test_fetch_review_comments.sh skills/review-pr/SKILL.md skills/review-pr/README.md skills/review-pr/docs/examples.md
git commit -m "test: lock review-pr additional review flow"
```
