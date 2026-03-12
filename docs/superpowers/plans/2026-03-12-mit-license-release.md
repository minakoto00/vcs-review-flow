# MIT License Release Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add MIT licensing metadata and documentation to the package before the `0.1.0` release.

**Architecture:** The change is limited to repository metadata and release-facing docs. A root MIT `LICENSE` file becomes the source of truth, `package.json` advertises the same license to npm, and the root README links users to the licensing terms.

**Tech Stack:** Markdown, npm package metadata, shell verification commands

---

## Chunk 1: Repository Licensing Metadata

### Task 1: Add the MIT license file and align package metadata

**Files:**
- Create: `LICENSE`
- Modify: `package.json`

- [ ] **Step 1: Add a standard MIT license file**

Create `LICENSE` with the canonical MIT text and the copyright holder `minakoto00`.

- [ ] **Step 2: Update package metadata**

Set `license` to `MIT` in `package.json` and keep the `bin` entry as `bin/skills.js` so the source file matches npm's packed manifest.

- [ ] **Step 3: Verify package metadata on disk**

Run: `node -p "require('./package.json').license + ' ' + require('./package.json').bin['minakoto-skills']"`
Expected: `MIT bin/skills.js`

## Chunk 2: Release Documentation And Verification

### Task 2: Document the license and verify release readiness

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a license section to the README**

Document that the repository and npm package are available under the MIT License and point readers to the root `LICENSE` file.

- [ ] **Step 2: Run the repository shell tests**

Run:
`bash tests/test_install_skill.sh`
`bash tests/test_npm_wrapper.sh`
`bash tests/test_fetch_review_comments.sh`
`bash tests/test_review_issue_clustering.sh`
`bash tests/test_review_validation_dispatch.sh`
Expected: each command prints `PASS`

- [ ] **Step 3: Verify the packed npm artifact**

Run: `npm pack --dry-run`
Expected: npm reports `@minakoto00/skills@0.1.0` and includes `LICENSE` in the tarball contents.

- [ ] **Step 4: Verify the publish path**

Run: `npm publish --dry-run --access public`
Expected: npm reports the package would publish successfully and any remaining failure is authentication only if the machine is not logged in.
