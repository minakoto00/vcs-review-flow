# Review PR Packaging Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure this repo into a multi-skill-ready layout, rename the current skill to `review-pr`, make `skills.sh` installation the primary path, add a branded `npx` convenience wrapper, and keep a fixed manual installer for power users.

**Architecture:** The repo root becomes package and maintainer space while the skill payload moves under `skills/review-pr/`. Installation is standardized around `npx skills add <repo> --skill review-pr`, with a small root npm CLI delegating to that command and a retained shell installer targeting the relocated skill directory. Existing shell-based tests remain the verification backbone, with new targeted tests for the installer and wrapper behaviors.

**Tech Stack:** Bash, shell-based test scripts, npm package metadata, Node.js CLI wrapper

---

## File Structure

### Canonical Skill Payload

- Create: `skills/review-pr/`
- Create: `skills/review-pr/SKILL.md`
- Create: `skills/review-pr/scripts/`
- Create: `skills/review-pr/docs/examples.md`

### Root Distribution And Tooling

- Create: `package.json`
- Create: `bin/skills.js`
- Modify: `README.md`
- Modify: `install-skill.sh`

### Tests

- Create: `tests/test_install_skill.sh`
- Create: `tests/test_npm_wrapper.sh`
- Modify: any existing shell tests that hard-code repo-root skill paths if needed

## Chunk 1: Move The Skill Into Canonical `skills/` Layout

### Task 1: Add a relocation safety test for the manual installer

**Files:**
- Create: `tests/test_install_skill.sh`
- Modify: `install-skill.sh`

- [ ] **Step 1: Write the failing test**

Add a shell test that runs:

```bash
bash install-skill.sh --agent codex --scope user-global --method symlink --dry-run
```

and asserts that:

```text
source_dir=/.../skills/review-pr
target_path=.../review-pr
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/test_install_skill.sh
```

Expected: FAIL because `install-skill.sh` still resolves the repo root and the old skill name.

- [ ] **Step 3: Move the skill payload into the new layout**

Move or recreate these files under the new canonical path:

```text
SKILL.md -> skills/review-pr/SKILL.md
scripts/*.sh -> skills/review-pr/scripts/*.sh
docs/examples.md -> skills/review-pr/docs/examples.md
```

Update `skills/review-pr/SKILL.md` so all relative script paths resolve from `skills/review-pr/`.

- [ ] **Step 4: Retarget the installer**

Update `install-skill.sh` so:

```bash
source_dir=$(normalize_path "$SCRIPT_DIR/skills/review-pr")
skill_name=review-pr
```

and keep the rest of the agent/scope logic intact.

- [ ] **Step 5: Run the relocation test again**

Run:

```bash
bash tests/test_install_skill.sh
```

Expected: PASS.

- [ ] **Step 6: Run the existing shell test suite that could regress from path changes**

Run:

```bash
bash tests/test_fetch_review_comments.sh
bash tests/test_review_issue_clustering.sh
bash tests/test_review_validation_dispatch.sh
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add skills/review-pr install-skill.sh tests/test_install_skill.sh
git commit -m "refactor: move review-pr skill into canonical layout"
```

### Task 2: Remove the root-level skill entrypoint cleanly

**Files:**
- Delete: `SKILL.md`
- Verify: `skills/review-pr/SKILL.md`

- [ ] **Step 1: Confirm all required skill content exists under `skills/review-pr/`**

Check:

```bash
find skills/review-pr -maxdepth 3 -type f | sort
```

Expected: all runtime scripts and docs needed by the skill are present there.

- [ ] **Step 2: Delete the old root entrypoint**

Remove:

```text
SKILL.md
```

- [ ] **Step 3: Verify the repo remains skills.sh-discoverable**

Run a lightweight repo structure check:

```bash
test -f skills/review-pr/SKILL.md
```

Expected: exit code `0`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: retire root skill entrypoint"
```

## Chunk 2: Fix The Shell Installer And Add The npm Wrapper

### Task 3: Add a failing test for interactive installer output hygiene

**Files:**
- Modify: `tests/test_install_skill.sh`
- Modify: `install-skill.sh`

- [ ] **Step 1: Extend the installer test to simulate interactive selection**

Use a TTY-friendly test approach such as piping defaults or numeric choices and assert the resulting variables do not contain menu text.

Representative assertion target:

```text
agent=codex
scope=user-global
method=symlink
```

- [ ] **Step 2: Run the installer test to verify it fails**

Run:

```bash
bash tests/test_install_skill.sh
```

Expected: FAIL because `choose_option()` currently prints menu text to stdout.

- [ ] **Step 3: Fix prompt and chooser output**

Update `install-skill.sh` so prompt text goes to stderr and stdout is reserved for the selected return value. A minimal pattern is:

```bash
printf '%s\n' "$prompt" >&2
printf '  %s. %s\n' "$index" "$option" >&2
read -r -p "> " answer </dev/tty
printf '%s\n' "$selected"
```

If `/dev/tty` handling is too brittle in tests, keep `read -r` on stdin but still move all non-value output to stderr.

- [ ] **Step 4: Re-run the installer test**

Run:

```bash
bash tests/test_install_skill.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add install-skill.sh tests/test_install_skill.sh
git commit -m "fix: clean up interactive installer output"
```

### Task 4: Add a failing test for the branded npm wrapper

**Files:**
- Create: `package.json`
- Create: `bin/skills.js`
- Create: `tests/test_npm_wrapper.sh`

- [ ] **Step 1: Write the failing wrapper test**

Create a shell test that runs:

```bash
node bin/skills.js install review-pr
```

and asserts that the program emits or executes the equivalent target:

```text
npx skills add <owner>/<repo> --skill review-pr
```

Choose one behavior and test exactly that:
- print the delegated command in dry-run mode, or
- spawn the delegated command via a stubbed `npx`

- [ ] **Step 2: Run the wrapper test to verify it fails**

Run:

```bash
bash tests/test_npm_wrapper.sh
```

Expected: FAIL because the package metadata and CLI do not exist yet.

- [ ] **Step 3: Add npm package metadata**

Create `package.json` with:

```json
{
  "name": "@minakoto00/skills",
  "bin": {
    "skills": "./bin/skills.js"
  }
}
```

Also include the fields needed for publishing and `npx` execution:
- `version`
- `type` if you choose ESM
- `files`
- `license`

- [ ] **Step 4: Implement the CLI wrapper**

Create `bin/skills.js` to support:

```text
@minakoto00/skills install review-pr
```

Behavior:
- accept `install review-pr`
- delegate to `npx skills add <owner>/<repo> --skill review-pr`
- reject unknown subcommands and unknown skill names with a non-zero exit code

- [ ] **Step 5: Re-run the wrapper test**

Run:

```bash
bash tests/test_npm_wrapper.sh
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add package.json bin/skills.js tests/test_npm_wrapper.sh
git commit -m "feat: add npx wrapper for review-pr installation"
```

## Chunk 3: Rewrite Docs Around The New Distribution Model

### Task 5: Update the root README to lead with `skills.sh`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite the installation section**

Replace the current installer-first section with:

```bash
npx skills add <owner>/<repo> --skill review-pr
```

and add updates:

```bash
npx skills check
npx skills update
```

- [ ] **Step 2: Add the branded convenience command**

Document:

```bash
npx @minakoto00/skills install review-pr
```

Label it clearly as a shortcut that delegates to the Skills CLI path.

- [ ] **Step 3: Reduce manual install docs to an advanced section**

Keep a short manual-install subsection with:

```bash
bash ./install-skill.sh
```

Mention that scripted flags still exist for power users, but remove the large non-interactive command matrix from the main README.

- [ ] **Step 4: Update naming throughout the README**

Replace mentions of `vcs-review-flow` with `review-pr` where they refer to the skill name, while preserving any repo-level naming that is intentionally broader.

- [ ] **Step 5: Review command examples for path correctness**

Ensure script examples refer to the canonical skill location when relevant and do not imply the repo root is the skill root.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: switch review-pr install guidance to skills.sh"
```

### Task 6: Update skill-local examples and compatibility docs

**Files:**
- Modify: `skills/review-pr/docs/examples.md`
- Modify: any moved docs under `skills/review-pr/`

- [ ] **Step 1: Rename the examples document**

Update the title and internal wording from `VCS Review Flow` to `Review PR` where appropriate.

- [ ] **Step 2: Fix installer examples**

Retain only examples that still make sense after the README simplification. If installer dry-run examples remain, ensure they reflect the new `review-pr` source directory and target name.

- [ ] **Step 3: Verify all relative references work from the new skill path**

Run:

```bash
rg -n "scripts/|docs/examples|vcs-review-flow|review-pr" skills/review-pr
```

Expected: no stale path assumptions remain.

- [ ] **Step 4: Commit**

```bash
git add skills/review-pr/docs
git commit -m "docs: update review-pr skill examples"
```

## Chunk 4: End-To-End Verification

### Task 7: Run final verification before claiming completion

**Files:**
- Verify: `README.md`
- Verify: `install-skill.sh`
- Verify: `package.json`
- Verify: `bin/skills.js`
- Verify: `skills/review-pr/`
- Verify: `tests/test_install_skill.sh`
- Verify: `tests/test_npm_wrapper.sh`

- [ ] **Step 1: Run the targeted new tests**

Run:

```bash
bash tests/test_install_skill.sh
bash tests/test_npm_wrapper.sh
```

Expected: PASS.

- [ ] **Step 2: Re-run the existing regression tests**

Run:

```bash
bash tests/test_fetch_review_comments.sh
bash tests/test_review_issue_clustering.sh
bash tests/test_review_validation_dispatch.sh
```

Expected: PASS.

- [ ] **Step 3: Smoke-test the manual installer dry run**

Run:

```bash
bash install-skill.sh --agent codex --scope user-global --method symlink --dry-run
```

Expected: output references `skills/review-pr` and a target ending in `/review-pr`.

- [ ] **Step 4: Smoke-test the npm wrapper**

Run one of:

```bash
node bin/skills.js install review-pr --dry-run
```

or, if the wrapper does not expose dry-run:

```bash
bash tests/test_npm_wrapper.sh
```

Expected: the wrapper clearly maps to the canonical Skills CLI install target.

- [ ] **Step 5: Inspect the final diff**

Run:

```bash
git status --short
git diff --stat
```

Expected: only the intended migration, installer, wrapper, and docs files are changed.

- [ ] **Step 6: Create the final implementation commit or merge the task commits**

Use the commit history created above, or if batching was necessary, finish with a final tidy commit:

```bash
git add -A
git commit -m "feat: package review-pr skill for skills.sh"
```

Plan complete and saved to `docs/superpowers/plans/2026-03-12-review-pr-packaging.md`. Ready to execute?
