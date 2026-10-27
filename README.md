# Sassy Agents

**The Sassy subagent roster — one directory per harness, one behavior in every harness, one roster on every provider.**

Sassy Agents is the source of truth for the subagents the Sassywares workflow dispatches: a grounding scout, an implementation worker, a reviewer, and a validator. Each agent is a Markdown file with frontmatter; each declares a `profiles:` list, so the same roster runs on DeepSeek by default and on Anthropic when a project opts in.

The repo is `sassy-agents`. The npm mirror is `@sassywares/agents`.

## Table of contents

- [Why this roster](#why-this-roster)
- [Quick start](#quick-start)
- [Agents](#agents)
- [How agents are found](#how-agents-are-found)
- [Model profiles](#model-profiles)
- [Grounding brief](#grounding-brief)
- [Harness layout](#harness-layout)
- [Adding or editing an agent](#adding-or-editing-an-agent)
- [Repository layout](#repository-layout)
- [Development](#development)
- [Repository maintenance](#repository-maintenance)
- [Provenance](#provenance)

## Why this roster

- **One job per agent.** Scout grounds, worker implements, reviewer judges quality, validator judges intent. None of them re-does another's work.
- **Isolated context.** Each is dispatched by the `subagent` tool from [`sassy-pi-extensions`](https://github.com/sassywares/sassy-pi-extensions), so each gets its own context window and returns a compact result.
- **Provider-agnostic.** Model choice lives in frontmatter `profiles:`, not in a branch or a separate roster. Swapping providers is a settings change.
- **Read-only by default.** Reviewer and validator get `read, grep, find, ls, bash`; only scout and worker can write.
- **Shared grounding.** Every agent reads one brief written by `scout` instead of re-exploring the repo. See [GROUNDING.md](GROUNDING.md).
- **Composable with [`sassy-skills`](https://github.com/sassywares/sassy-skills).** The skills dispatch these agents by name — `scout`, `worker`, `reviewer`, `validator`.

## Quick start

Clone the repo next to your work and link the roster for your harness:

```bash
git clone https://github.com/sassywares/sassy-agents.git
./sassy-agents/scripts/install.sh          # pi → ~/.pi/agent/agents/
./sassy-agents/scripts/install.sh claude   # Claude Code → ~/.claude/agents/
```

`sassy-setup` (in `sassy-skills`) checks for the roster and offers this link, or a per-project copy into `.pi/agents/` / `.claude/agents/`.

`install.sh` symlinks `pi/*.md` into `~/.pi/agent/agents/`. Editing this repo changes the running agents on the next subagent invocation — there is no copy to keep in sync.

Then install the extensions that dispatch them, if you have not already:

```bash
pi install npm:@sassywares/pi-extensions
```

Reload pi (`/reload`) and confirm the `subagent` tool lists the Sassy agents.

A package-only install of `@sassywares/agents` works too when you would rather pin a version than link a checkout:

```bash
npm install --save-dev @sassywares/agents@0.1.0
./node_modules/@sassywares/agents/scripts/install.sh
```

Pi does not load agents from packages on its own; the link step is what makes them visible.

## Agents

| Agent | Role | pi `deepseek` profile | pi `anthropic` profile | Claude Code `model` |
|---|---|---|---|---|
| `scout` | Grounding scout: writes the shared grounding brief other agents read, including matching prior learnings from the project's `.sassywares/config.yaml` knowledge paths. | `deepseek/deepseek-flash` | `anthropic/claude-haiku-4-5` | `haiku` |
| `worker` | General-purpose implementation in an isolated context. | `deepseek/deepseek-flash` | `anthropic/claude-sonnet-4-5` | `sonnet` |
| `reviewer` | Quality, correctness, security, project-rule, and design-system review, diff-scoped. | `deepseek/deepseek-flash` | `anthropic/claude-opus-4-5` | `opus` |
| `validator` | Checks that the diff matches the plan, independent of review. | `deepseek/deepseek-flash` | `anthropic/claude-sonnet-4-5` | `sonnet` |

Each file's body is the system prompt. Keep it to the role, hard rules, scope, and return shape — the orchestrating skill supplies the task. The body is identical in every harness directory; only the frontmatter is harness-specific, and CI fails on drift.

## How agents are found

Claude Code discovers agents from `~/.claude/agents/` (user) and the project's `.claude/agents/` (project, which wins on a name clash).

In pi, the `subagent` extension discovers agents from:

- `~/.pi/agent/agents/` — user scope, where `scripts/install.sh` links this roster.
- The nearest project `.pi/agents/` — project scope, which overrides a user agent with the same name.

`PI_AGENTS_DIR` overrides the user target when linking, which is useful in a container or a test harness. The extension's `agentScope` parameter (`user`, `project`, `both`) decides which of the two a dispatch sees; the default is `both`.

## Model profiles

A dispatch picks a profile — a named model choice — and the child process starts on that profile's model.

Pick a profile three ways, highest precedence first:

1. The tool call: `{ agent: "worker", task: "…", profile: "anthropic" }`. Individual `tasks[]` and `chain[]` entries accept `profile` too.
2. An environment variable: `PI_SASSY_PROFILE=anthropic`.
3. A project setting in `.pi/settings.json`, which is where a project opts in once for everyone:

   ```json
   { "sassy": { "profile": "anthropic" } }
   ```

   Project settings override `~/.pi/agent/settings.json`; with neither set, the default profile is `deepseek`.

A profile an agent does not define is an error naming the ones it does — it never falls back to the default provider. The run footer shows the model and, in parentheses, the profile it came from.

Every agent must define every profile a project may select. Adding a profile is a frontmatter edit in each file you want it to apply to:

```yaml
profiles:
  - name: deepseek
    model: deepseek/deepseek-flash
    thinking: low
  - name: anthropic
    model: anthropic/claude-sonnet-4-5
    thinking: low
```

Rules:

- Profile names are lowercase letters, digits, and dashes, and must be unique within an agent.
- `model` is always `provider/id`; `thinking` is one of `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`.
- `profiles:` and `model:` are mutually exclusive — pinning a model and offering profiles at once is a parse error.
- A pinned `model:` (plus optional `thinking:`) is still supported for personal agents and ignores profile selection.
- Neither key means the agent inherits the dispatcher's model and thinking.

## Grounding brief

Every agent in a run reads one shared brief instead of exploring the repo for itself. `scout` writes it; `worker`, `reviewer`, and `validator` consume it. It lives in a per-user temp directory keyed by the absolute repo or worktree root, so it never touches the repo and two worktrees never collide.

[GROUNDING.md](GROUNDING.md) defines the location, the freshness check, and the wait rule. A missing or stale brief is reported, never papered over.

## Harness layout

One directory per harness: `pi/` and `claude/`. Every directory carries the full roster with identical bodies; only frontmatter differs.

```text
sassy-agents/
├── pi/                  # pi subagent definitions
│   ├── scout.md
│   ├── worker.md
│   ├── reviewer.md
│   └── validator.md
├── claude/              # Claude Code subagent definitions (same four)
├── scripts/
│   ├── install.sh       # links one harness's agents into place
│   ├── sync.sh          # bump, commit, push, tag
│   └── test-profiles.mjs
└── …
```

`scripts/install.sh <harness>` takes `pi` (the default) or `claude` and rejects a harness it does not know, rather than guessing a target directory.

## Adding or editing an agent

1. Create or edit the agent in every harness directory: `pi/<name>.md` (`profiles:` or a pinned `model:`) and `claude/<name>.md` (Claude Code `tools` and a `model:` alias).
2. Keep the frontmatter `name` equal to the file name.
3. Keep the body focused on the role, hard rules, scope, and return shape — and byte-identical across harnesses.
4. Update the roster table in `README.md`.
5. Run `./scripts/install.sh` once if the agent is new, then `./scripts/sync.sh` to commit and release.

Agents that write should say so in `tools:`: `scout` needs `write` (`Write` in Claude Code) for the brief, `worker` needs the full toolset. Reviewer and validator stay read-only so a review cannot change the diff it is judging.

## Repository layout

```text
sassy-agents/
├── pi/
│   └── *.md
├── claude/
│   └── *.md
├── scripts/
│   ├── install.sh
│   ├── sync.sh
│   └── test-profiles.mjs
├── .github/workflows/
│   └── publish.yml
├── AGENTS.md
├── CONCEPTS.md
├── GROUNDING.md
├── LICENSE
├── NOTICE
├── README.md
└── package.json
```

| Path | Role |
|---|---|
| `pi/*.md` | The pi roster. Linked into `~/.pi/agent/agents/`. |
| `claude/*.md` | The Claude Code roster. Linked into `~/.claude/agents/`. |
| `scripts/install.sh` | Symlinks one harness's agents into that harness's user directory. |
| `scripts/sync.sh` | Bumps, commits, pushes, tags, and releases. |
| `scripts/test-profiles.mjs` | Checks agent parsing and profile resolution against the real roster plus malformed fixtures. |
| `.github/workflows/publish.yml` | Validates the roster and publishes on a `v*` tag. |
| `GROUNDING.md` | The shared grounding brief contract. |
| `package.json` | npm mirror manifest. |

## Development

Agents are read from disk on every dispatch, so there is no build step. Link the working tree once:

```bash
./scripts/install.sh
```

After editing an agent, dispatch it through the `subagent` tool. After changing parsing or profile behavior, run the checks:

```bash
./scripts/test-profiles.mjs
```

The script copies `agents.ts` from a `sassy-pi-extensions` checkout — found as a sibling directory, through `PI_EXTENSIONS_DIR`, or in an install — plus the real roster into a temporary project, and exercises discovery, profile resolution, precedence, and every rejected frontmatter shape. It needs the pi install for peer packages; set `PI_PEER_MODULES` if it cannot find one.

## Repository maintenance

`scripts/sync.sh` bumps the patch version when shipped content changed, commits, pushes `main`, then tags and pushes the tag — so a roster change is released in one step. Any agent that changes the roster must run it immediately, without asking for confirmation.

```bash
~/Documents/Workspace/Sassywares/sassy-agents/scripts/sync.sh
```

Releases only happen on `main`. On any other branch the script commits and pushes without tagging, because a tag pushed from a feature branch would publish unmerged content to npm. It installs nothing: consumers get a change when they run `./scripts/install.sh` after pulling, and the npm mirror follows the tag.

### Releasing

Publishing is tag-driven and uses npm trusted publishing (OIDC). `publish.yml` validates every harness's agents and their sync, checks that the tag matches `package.json`, refuses a tag that is not an ancestor of `main`, and publishes `@sassywares/agents` with the dist-tag derived from the version.

`scripts/sync.sh` does this for you on `main`. The manual sequence is the fallback for recovering a failed run:

```bash
npm version patch --no-git-tag-version
git add -A && git commit -m "chore: release v$(node -p "require('./package.json').version")"
git push origin main
git tag "v$(node -p "require('./package.json').version")"
git push origin --tags
```

The first publish of a new package needs a manual `npm publish --access public` bootstrap before npm's trusted-publisher settings exist. `AGENTS.md` documents the full workflow for agents working on this repo.

## Provenance

The agent definitions under `pi/` and `claude/` are derived from pi's MIT-licensed examples and documentation, modified for this workflow. See [NOTICE](NOTICE).
