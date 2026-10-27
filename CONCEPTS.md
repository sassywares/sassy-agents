# Sassy Agents — Concepts

## Source of truth

Each harness directory is the only copy of that harness's roster. `scripts/install.sh <harness>` symlinks each file into the harness's user agent directory (`~/.pi/agent/agents/`, `~/.claude/agents/`), so the running agents are the working tree.

## Agent

A Markdown file with `name` and `description` frontmatter, plus optional `tools`, `model`, `thinking`, and `profiles`. The body is the system prompt. One file, one role. See the [pi agent format](https://github.com/earendil-works/pi).

## Harness

A directory at the repo root named after the tool that consumes it: `pi/` for pi, `claude/` for Claude Code. Every harness directory holds the full roster. Harnesses differ in frontmatter and discovery only: an agent's body — what it does — is identical in every harness, and CI fails when it drifts.

## Roster

The four agents shipped here — `scout`, `worker`, `reviewer`, `validator` — and the contract that they cover a unit of work end to end: ground it, implement it, review it, validate it against intent.

## Profile

A named model choice inside an agent's `profiles:` list, such as `deepseek` or `anthropic`. A dispatch selects a profile; the agent's entry supplies the model and thinking level for that provider. Profiles are how one roster runs on several providers without a branch or a second copy.

## Profile selection

The precedence that resolves which profile a dispatch runs: the tool call's `profile` parameter, then `PI_SASSY_PROFILE`, then `sassy.profile` in project settings, then user settings, then the default `deepseek`. A missing profile is an error naming the available ones — never a silent fallback.

## Scope

Where an agent is discovered from. `user` is `~/.pi/agent/agents/`, the target of `scripts/install.sh`. `project` is the nearest project `.pi/agents/`, which overrides a user agent of the same name. The `subagent` tool takes `user`, `project`, or `both`; the default is `both`.

## Grounding brief

One file per repo or worktree, under `/tmp/sassywares/<harness>/grounding/`, written by `scout` and read by every other agent in the run. It carries project evidence with `file:line` citations so consumers do not repeat discovery. Location, freshness, and wait rules are in [GROUNDING.md](GROUNDING.md).

## Subagent

The tool from `@sassywares/pi-extensions` that spawns one pi process per task and returns compact output. Modes are single, parallel, and chain. This repo supplies the agents it dispatches; it does not implement the tool.

## Orchestrator

A skill from `sassy-skills` that coordinates: it decides which agents to dispatch, writes the brief, and keeps the main context small. Orchestrators live in the skills repo, not here.

## Upstream derivation

The roster is a modified version of pi's MIT-licensed examples and documentation. `NOTICE` records the attribution; `LICENSE` covers this repository.
