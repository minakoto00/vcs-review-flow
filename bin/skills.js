#!/usr/bin/env node

const { spawnSync } = require("node:child_process");

const REPOSITORY = "minakoto00/vcs-review-flow";
const SUPPORTED_SKILLS = new Set(["review-pr"]);

function usage() {
  console.error("Usage: @minakoto00/skills install <skill-name> [--dry-run]");
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function buildInstallArgs(skillName) {
  return ["skills", "add", REPOSITORY, "--skill", skillName];
}

function npxCommand() {
  return process.platform === "win32" ? "npx.cmd" : "npx";
}

const args = process.argv.slice(2);
const dryRunIndex = args.indexOf("--dry-run");
const dryRun = dryRunIndex !== -1;

if (dryRun) {
  args.splice(dryRunIndex, 1);
}

const [command, skillName] = args;

if (command !== "install" || !skillName || args.length !== 2) {
  usage();
  process.exit(1);
}

if (!SUPPORTED_SKILLS.has(skillName)) {
  fail(`unsupported skill: ${skillName}`);
}

const installArgs = buildInstallArgs(skillName);
const renderedCommand = [npxCommand(), ...installArgs].join(" ");

if (dryRun) {
  console.log(renderedCommand);
  process.exit(0);
}

const result = spawnSync(npxCommand(), installArgs, { stdio: "inherit" });

if (result.error) {
  fail(result.error.message);
}

process.exit(result.status ?? 1);
