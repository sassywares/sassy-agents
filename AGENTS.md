# Sassy Agents — Agent Guide

## What this repo is

This repo is the source of truth for the Sassy subagent roster, laid out one directory per harness: `pi/` and `claude/` (Claude Code).

- Local: `~/Documents/Workspace/Sassywares/sassy-agents`
- Remote: `sassywares/sassy-agents`
- Package: `@sassywares/agents`

Consumers clone this repo and run `scripts/install.sh <harness>`, which symlinks `<harness>/*.md` into that harness's user agent directory (`~/.pi/agent/agents/`, `~/.claude/agents/`). A project may instead vendor a harness folder into its own `.pi/agents/` or `.claude/agents/`; `sassy-setup` in `sassy-skills` offers both. Do not keep a second copy in the same scope: the harness would load two definitions of the same agent, and one would silently lose.

In pi, the roster is dispatched by the `subagent` extension in [`sassy-pi-extensions`](https://github.com/sassywares/sassy-pi-extensions), which owns discovery, parsing, and profile resolution. In Claude Code, the built-in Agent tool dispatches them by name. This repo owns the agents themselves.

## Harnesses stay in sync

Every harness directory carries the **same roster doing the same job**. The rule is strict:

- **Same agents everywhere.** An agent that exists in one harness directory exists in all of them, under the same file name. Adding or removing an agent is one change across every harness.
- **The body is identical.** Everything after the closing `---` — the role, scope, rules, grounding, and output format — is byte-for-byte the same file content in every harness. What an agent does never depends on which harness runs it.
- **Only the frontmatter differs.** Each harness gets the frontmatter it expects: pi takes `tools: read, grep, …` and `profiles:`; Claude Code takes `tools: Read, Grep, …` and a `model:` alias. Translate intent, not text: a read-only agent stays read-only in every harness, and model tiers map across (the pi `anthropic` profile's model is the Claude Code `model:`).
- **Edit once, copy across.** Change the body in one harness, then copy it to the others in the same commit. Never let a harness carry a fix the others lack.

CI enforces this: `publish.yml` fails when an agent is missing from a harness or when two harnesses' bodies differ.

## Branches: `main` only

`main` is the only branch and the only release line. There is no provider-specific branch and no provider-specific roster.

Provider choice is configuration, not a branch:

- Every agent under `pi/` declares a `profiles:` list — the model choices it can run on, one entry per provider.
- Which profile a dispatch uses is decided at run time: the `subagent` tool's `profile` parameter, then `PI_SASSY_PROFILE`, then `sassy.profile` in settings, then the built-in default `deepseek`.
- A project that wants another provider sets it once in its own settings file:

  ```json
  { "sassy": { "profile": "anthropic" } }
  ```

  `<project>/.pi/settings.json` overrides `~/.pi/agent/settings.json`, so a project opts into Anthropic (or anything else) without touching this repo.

Rules:

- **Never reintroduce a provider branch.** Model choice belongs in `profiles:`, not in git history. A model swap is a one-line frontmatter edit on `main`.
- **Every agent must define every profile a project may select.** A missing profile is an error naming the available ones; it is never a silent fallback to the default provider.
- **The default stays OSS.** `DEFAULT_PROFILE` in the extension is `deepseek`; Anthropic is opt-in per project or per dispatch.

## Layout

```text
sassy-agents/
├── pi/
│   ├── reviewer.md
│   ├── scout.md
│   ├── simplifier.md
│   ├── validator.md
│   └── worker.md
├── claude/
│   └── (same five agents, Claude Code frontmatter)
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
| `scripts/sync.sh` | Bumps, commits, pushes, tags, and releases. See [Sync](#sync). |
| `scripts/test-profiles.mjs` | Checks agent parsing and profile resolution against the real roster plus malformed fixtures. |
| `.github/workflows/publish.yml` | Validates every harness's roster and their sync, then publishes on a `v*` tag. |
| `GROUNDING.md` | The shared grounding brief contract every roster agent follows. |
| `package.json` | npm mirror manifest. Ships `pi/`, `claude/`, `scripts/`, and the docs. |

`package.json` deliberately has no `pi` manifest: pi does not load agents from packages, so the roster is linked, not installed. The npm package is a versioned mirror for consumers that pin a version.

## Adding or editing an agent

1. Create or edit the agent in **every** harness directory (see [Harnesses stay in sync](#harnesses-stay-in-sync)):
   - `pi/<name>.md` — `name`, `description`, optional `tools`, and either a `profiles:` list or a pinned `model:`.
   - `claude/<name>.md` — `name`, `description`, optional `tools` (Claude Code tool names; omit to inherit all), and `model:` (`haiku`, `sonnet`, `opus`, or `inherit`).
2. Keep the frontmatter `name` equal to the file name; CI checks it.
3. Keep the body focused on the role, hard rules, scope, and return shape — and identical across harnesses.
4. Run `./scripts/install.sh <harness>` once per harness if the agent is new.
5. Update the roster table in `README.md`.
6. Run `./scripts/test-profiles.mjs` when parsing or profiles changed.
7. Run `./scripts/sync.sh` immediately. Do not ask the user first.

A switchable agent declares one entry per provider. Every selectable profile must be defined, because a project that selects a missing profile gets an error, not a fallback:

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
- Reviewer, simplifier, and validator stay read-only. Do not add `write`, `edit`, or `codemode` to them.

## Adding a harness

1. Create `<harness>/` with the full roster: every agent, each body copied verbatim from `pi/`, frontmatter written for that harness.
2. Teach `scripts/install.sh` about the harness in its `case`, with an explicit target directory. Unknown harnesses must fail, never guess.
3. Add the directory to `harnesses` in `publish.yml`'s validation step so the sync check covers it.
4. Document the layout in `README.md` and `CONCEPTS.md`.
5. Add the directory to `files` in `package.json` and to `PUBLISHED_PATHS` (and the untracked-file check) in `scripts/sync.sh`.
6. Teach `sassy-setup` in `sassy-skills` the harness's user and project agent directories.

## Editing or removing

- Edit the agent in every harness directory in the same change.
- To remove an agent, delete `<harness>/<name>.md` from every harness, and its symlink under each harness's user agent directory.
- Do not create per-agent copies. `scripts/install.sh` is the only install path.
- Do not add a build step. Agents are plain Markdown.

## Testing

There is no test runner. Verify manually:

- `./scripts/install.sh` links every `pi/*.md` into `~/.pi/agent/agents/`; `./scripts/install.sh claude` links every `claude/*.md` into `~/.claude/agents/`.
- In Claude Code, `/agents` lists `scout`, `worker`, `reviewer`, `simplifier`, and `validator`.
- `pi -e ~/Documents/Workspace/Sassywares/sassy-pi-extensions` loads, and `subagent` lists every roster agent.
- `./scripts/test-profiles.mjs` passes; it covers agent parsing, profile precedence, and the error for a missing profile. It needs a `sassy-pi-extensions` checkout (sibling, `PI_EXTENSIONS_DIR`, or an install).
- A dispatch with `profile: "anthropic"` runs the Anthropic model shown in the run line, and the same dispatch with `profile: "nope"` fails with the available profile names.
- `PI_SASSY_PROFILE=anthropic` and `{"sassy":{"profile":"anthropic"}}` in `<project>/.pi/settings.json` both select Anthropic without a parameter.
- Reviewer, simplifier, and validator refuse to write, in every harness.

## Sync

There is no background watcher. Any agent that adds, edits, or removes an agent **must run `scripts/sync.sh` immediately as part of the change, without asking the user for confirmation**.

The sync script, in one unattended step:

1. Bumps the patch version when anything consumers receive changed since the last tag — `pi/`, `claude/`, `README.md`, `CONCEPTS.md`, `GROUNDING.md`, `NOTICE`, `LICENSE`, or `package.json`. A change to tooling, CI, or `AGENTS.md` commits without a version, because nothing a consumer links changed.
2. Commits every repo change with a `chore: sync agents <timestamp> (v<version>)` message.
3. Pushes the branch, then tags and pushes `v<version>`.
4. If the current version is already bumped but untagged — an interrupted run, or a hand-written bump — it tags that version instead of bumping again.

Releases only happen on `main`. On any other branch the script commits and pushes without tagging. It does not link anything anywhere.

```bash
~/Documents/Workspace/Sassywares/sassy-agents/scripts/sync.sh
```

If a push fails, the local commit remains, the script exits non-zero, and the next sync retries. Because the bump is already in `package.json`, the retry tags that version rather than bumping twice. Report the failure instead of leaving the change uncommitted.

## Publishing

Publishing is tag-driven. `.github/workflows/publish.yml` validates every harness's agents and that their bodies match, checks that the tag matches `package.json`, requires the tagged commit to be an ancestor of `main`, and publishes `@sassywares/agents` with provenance through npm trusted publishing (OIDC). There is no `NPM_TOKEN` secret.

Release checklist (from `main`):

1. Bump `version` in `package.json` — `sync.sh` does this.
2. Commit and push `main`.
3. Tag and push: `git tag -a v0.1.1 -m v0.1.1 && git push origin v0.1.1`.
4. Watch the Publish workflow under the repo's Actions tab.
5. Confirm `npm view @sassywares/agents version` equals the new version.

`scripts/sync.sh` makes steps 1–3 one action. If a bump is ever found untagged, tag it immediately rather than bumping again.

The stable version publishes to `latest`; a prerelease publishes under the dist-tag named by its identifier (`0.2.0-beta.1` → `beta`) and may never use `latest`.

The first publish needs a one-time manual bootstrap (`npm publish --access public`) because a trusted publisher can only be configured after the package exists. A new trusted publisher must complete its first OIDC publish within 2 days of configuration.

## Conventions

- **Roster for a role, not a provider.** One file per job per harness; provider differences live in frontmatter.
- **One behavior across harnesses.** Bodies are identical; only frontmatter is harness-specific.
- **Read-only reviews.** Reviewer, simplifier, and validator never write, so a review cannot change the diff it judges.
- **Shared grounding.** Agents read the brief, not the repository. See `GROUNDING.md`.
- **No secrets.** Never put credentials, tokens, or private keys in an agent.
- **No copies within a scope.** The linked checkout is the only user-scope roster; remove any duplicate under a harness's user agent directory.
- **Attribute upstream.** The roster is derived from pi. Keep `NOTICE` current when it changes.
