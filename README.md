# VCS Review Flow

`VCS Review Flow` is a `skills.sh`-ready repository of skills for reviewing GitHub pull requests and GitLab merge requests through local worktrees. Install the skill you need, then follow the skill-local guide for workflow details.

## Quickstart

Primary install:

```bash
npx skills add minakoto00/vcs-review-flow --skill review-pr
```

Optional shortcut:

```bash
npx @minakoto00/skills install review-pr
```

## Available Skills

- `review-pr`: Review the latest open PR or MR in a dedicated worktree and turn remote feedback into a validated change plan. See `skills/review-pr/README.md`.

## Updates

```bash
npx skills check
npx skills update
```

## Advanced Manual Install

For local development or power users, the repo still includes `install-skill.sh`.

```bash
bash ./install-skill.sh
```

Use `bash ./install-skill.sh --help` for scripted flags and dry-run options.

## Repository Layout

- `skills/review-pr/README.md`: full guide for the `review-pr` skill
- `skills/review-pr/SKILL.md`: skill entrypoint used by agents
- `skills/review-pr/scripts/`: helper scripts used by the skill workflow
- `install-skill.sh`: advanced manual installer
- `bin/skills.js`: npm wrapper for `npx @minakoto00/skills install review-pr`

## License

This repository and the published `@minakoto00/skills` package are available under the MIT License. See `LICENSE`.
