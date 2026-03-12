# MIT License Release Design

**Goal:** Add an MIT license to the repository and npm package before the `0.1.0` release so published metadata and repository documentation agree.

## Scope

- Add a standard MIT license file at the repository root.
- Update npm package metadata to publish as MIT-licensed.
- Document the license in the root README.
- Preserve the normalized npm `bin` path that `npm publish --dry-run` already wrote into `package.json`.

## Files

- Create: `LICENSE`
- Modify: `package.json`
- Modify: `README.md`

## Design

The repository will declare MIT in the standard three places npm users expect: a root `LICENSE` file, the `license` field in `package.json`, and a short note in the root README. The package `bin` path will remain `bin/skills.js`, matching the packed manifest npm generates during publish validation.

## Verification

- Run the existing shell test suite.
- Run `npm pack --dry-run` and confirm the package advertises `license: MIT`.
- Run `npm publish --dry-run --access public` and confirm the publish path remains valid apart from npm authentication.
