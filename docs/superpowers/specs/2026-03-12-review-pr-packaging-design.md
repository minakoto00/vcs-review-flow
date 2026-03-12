---
title: Review PR Packaging Design
date: 2026-03-12
---

# Review PR Packaging Design

## Goal

Restructure this repository from a single root-level skill into a multi-skill-ready repository, rename the current skill to `review-pr`, simplify the README installation guidance, and support both the standard `skills.sh` install path and a branded `npx` convenience command.

## Scope

This design covers:

- skill renaming from `vcs-review-flow` to `review-pr`
- repository layout changes for a future multi-skill repo
- README installation and update guidance
- an optional npm wrapper command for direct `npx` installation
- fixes to the existing interactive shell installer

This design does not cover:

- behavioral changes to the review workflow itself
- new review automation features
- publishing or packaging additional skills beyond `review-pr`

## Current State

- The repository is structured as a single skill rooted at `SKILL.md`.
- `README.md` advertises `install-skill.sh` as the main install path and includes a long non-interactive flag matrix.
- `install-skill.sh` assumes the repo root is the skill root.
- The repository does not contain `package.json` or an npm entrypoint.
- The current interactive installer likely breaks because menu text is emitted on stdout while selected values are captured through command substitution.

## Constraints

- The canonical public install path should align with `skills.sh` conventions.
- The repository should be ready to host additional skills later without another structural migration.
- The user should still be able to install via a branded `npx` command.
- The manual shell installer should remain available for power users and local development.
- The README should stop advertising the non-interactive install matrix.

## Research Summary

As of March 12, 2026, the common `skills.sh` pattern is:

- structure skills under `skills/<skill-name>/SKILL.md`
- install with `npx skills add <owner>/<repo> --skill <skill-name>`
- update with `npx skills check` and `npx skills update`

Public examples and documentation emphasize repo-based installation through the Skills CLI rather than custom package-specific installers. A branded npm command is viable as a convenience layer, but it should delegate to the Skills CLI instead of creating a second independent install and update system.

## Design

### Skill Naming

Rename the skill from `vcs-review-flow` to `review-pr`.

Rationale:
- short and easy to type
- clear enough for discovery in a multi-skill repo
- acceptable even though the skill supports both PRs and MRs, because the description can state that explicitly

Canonical identifiers:
- skill directory: `skills/review-pr/`
- skill frontmatter name: `review-pr`
- public install command: `npx skills add <owner>/<repo> --skill review-pr`

### Repository Layout

Adopt a canonical multi-skill-ready layout:

```text
/
  README.md
  package.json
  install-skill.sh
  scripts/
  skills/
    review-pr/
      SKILL.md
      scripts/
      docs/
```

Rules:
- `skills/review-pr/` is the only canonical skill payload.
- The repo root is reserved for package metadata, maintainer docs, wrapper tooling, and optional shared utilities.
- Skill-local runtime assets move under `skills/review-pr/` unless they are intentionally shared across future skills.
- The old root-level `SKILL.md` is retired rather than maintained as a compatibility alias.

### Installation Model

Use a layered installation model with one authoritative path.

Primary public path:
- install with `npx skills add <owner>/<repo> --skill review-pr`
- update with `npx skills check` and `npx skills update`

Secondary convenience path:
- install with `npx @minakoto00/skills install review-pr`
- this command delegates to the equivalent Skills CLI install flow
- it is documented as a convenience alias, not as the canonical distribution mechanism

Manual fallback:
- keep `install-skill.sh`
- reposition it as an advanced or local-development option
- do not feature its non-interactive flag matrix in the README

### npm Wrapper Responsibilities

Add a small npm package at the repo root to support the branded `npx` command.

The wrapper should:
- expose a CLI command that accepts `install review-pr`
- map that request to the repository’s canonical Skills CLI install command
- fail clearly for unsupported skill names
- avoid copying files directly into agent directories
- avoid defining a separate update workflow

The wrapper should not:
- become the source of truth for skill contents
- reimplement the shell installer
- diverge from `skills.sh` naming or install semantics

### README Simplification

Rewrite `README.md` so installation guidance is concise and aligned with the new distribution model.

README changes:
- lead with `npx skills add <owner>/<repo> --skill review-pr`
- document updates via `npx skills check` and `npx skills update`
- mention `npx @minakoto00/skills install review-pr` as an optional shortcut
- keep a brief advanced section for the manual shell installer
- remove the non-interactive installation command matrix from the main documentation

The README should still mention that the shell installer supports scripted flags, but it should not showcase the full set of commands.

### Shell Installer Changes

Keep `install-skill.sh`, but retarget it to the canonical skill directory.

Required changes:
- derive `source_dir` from `skills/review-pr/` rather than the repo root
- ensure installed directory naming matches `review-pr`
- fix interactive prompts so menus and prompt text go to stderr while stdout is reserved for returned values
- preserve existing agent, scope, method, project-root, conflict, and dry-run behaviors

This keeps the shell installer useful for power users without making it the main onboarding path.

### Compatibility Strategy

Use a clean-break migration.

Rules:
- retire the old skill name `vcs-review-flow`
- do not keep a root-level compatibility shim
- expect existing manual users to reinstall from the new canonical location
- keep the npm wrapper focused on `review-pr` only

This avoids duplicate sources of truth and reduces long-term maintenance.

## Data And Path Implications

- Any relative script references inside `SKILL.md` must be updated to resolve from `skills/review-pr/`.
- Any docs or examples that assume the repo root is the skill root must be updated or moved.
- If helper assets remain shared at the root, skill docs must reference them intentionally and clearly.

## Testing

Verification should cover:

- the repository is discoverable through the `skills/` layout
- `install-skill.sh --dry-run` resolves `skills/review-pr/` as the source directory
- interactive installer prompts return clean values in a TTY session
- the npm wrapper maps `install review-pr` to the correct Skills CLI target
- README commands match the actual supported install and update flows

## Rollout

The change should be shipped as a single migration so the repo layout, README guidance, installer behavior, and npm wrapper all point at the same canonical skill name and location.
