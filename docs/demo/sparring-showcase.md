# Agent Sparring showcase — SocialCircle

A faithful, sanitized record of how SocialCircle is being built through
Agent Sparring: what was set up, what the plan says, what the independent
reviewer actually decided, which commits were accepted, and what could not
be verified. Nothing in this file is reconstructed from memory; every
execution claim cites an engine artifact or a command output.

Status legend: **verified** = observed in this environment; **pending** =
not executed yet; **unavailable** = the tools do not expose it.

## 1. Tool versions and revisions (verified, 2026-10-14)

| Tool | Version / revision | How obtained |
| --- | --- | --- |
| agent-sparring engine | `agent-sparring==0.1.0`, Git `c4fb297947d0a58d3e7c73574e6c79a979a5cd1d` (2026-10-09, "docs: plan repository-owned managed execution") | `git clone https://github.com/sigmundas/agent-sparring.git`; `uv tool install --editable ./agent-sparring` (editable, so the checkout *is* the installed engine) |
| agent-sparring Claude Code plugin | 0.1.0, same commit `c4fb297…` | `claude plugin marketplace add sigmundas/agent-sparring`; `claude plugin install agent-sparring@agent-sparring` |
| agent-sparring-vscode | `agent-sparring-vscode-0.1.0.vsix`, Git `e4bb264d67d550cf17feb771d1bb223228cdc7cc` (2026-10-08) | `npm install && npm run package:vsix && npm run check:vsix -- agent-sparring-vscode-0.1.0.vsix`; `code --install-extension …` → `sintef.agent-sparring-vscode@0.1.0` |
| Claude Code CLI | 2.1.299, signed in (claude.ai) | `claude --version`, `claude auth status` |
| Codex CLI | 0.158.0, "Logged in using ChatGPT" | `codex --version`, `codex login status` |
| VS Code | 1.139.0 | `code --version` |
| uv / Python | uv 0.13.1 / CPython 3.13.5 | `uv --version`, `uv python list` |
| Node / npm | 25.9.0 / 11.17.0 (nvm) | |
| Docker / Compose | 29.8.1 / v5.5.1 | |
| Git | 2.47.3 | |

Engine invocation facts (read from the engine source at that revision):
the stage agent runs `claude -p <prompt> --output-format stream-json
--verbose --permission-mode acceptEdits [--model] [--effort] [--resume
<session>]`; the reviewer runs `codex exec … --json -c
sandbox_mode="read-only"` (OS-enforced read-only, also on resume). Because
headless Claude cannot ask for tool permissions, this repository ships
`.claude/settings.json` with an explicit allowlist (`make`, `uv`, `npm`,
`docker`, `git commit`, …) and a denylist (`git push`, branch switching,
editing `docs/plans/` or `.sparring/`).

## 2. Project setup (verified)

```text
socialcircle/            this repository (git init -b main)
../agent-sparring/       engine checkout, outside the repository
../agent-sparring-vscode/ extension checkout, outside the repository
```

Commands run in `socialcircle/` and their results:

| Command | Result |
| --- | --- |
| `sparring init-config --project socialcircle` | wrote `.sparring/project.toml` (stage `claude-cli`, sparring `codex-cli`, `[repo] root = "."`) |
| `sparring fix-config` | "nothing to fix" — `.gitignore` already ignored `.sparring/stages/`, `plans/`, `intake/` |
| `sparring check-config` | exit 0; `stage artifacts git-ignored: yes`, `plan-run state git-ignored: yes`, `plan intake git-ignored: yes`; PROJECT.md present after bootstrap; user preferences file `~/.config/agent-sparring/config.toml` (absent → provider defaults) |
| `sparring show-config --json` | `setup_problems: []` |
| `sparring start-plan docs/plans/socialcircle-mvp.md --managed --json` (read-only preflight, no `--confirm`) | `status: ready`, `route: direct`, six implementation stages, `managed.target_branch: main`, `base_sha: f782b68…`, `permission_mode: acceptEdits`, `max_send_back_cycles: 5`; nothing written |
| `sparring runs --json` | `{"runs": []}` — no managed run started yet |
| `make check` | exit 2: `error: backend/ does not exist yet — it is created by Stage 1 …` (the honest pre-Stage-1 baseline, recorded in `.sparring/PROJECT.md`) |

Bootstrap commit on `main`: `f782b68` ("Bootstrap SocialCircle: architecture, API
contract, agent instructions, Agent Sparring config and staged plan").

Model and effort: no preference saved; both roles run at the provider's own
default. The engine records what each turn actually resolved to in the
stage's `state.json` (`agents`) and `activity.jsonl` (`agents.resolved`).

## 3. Approved plan (verified)

`docs/plans/socialcircle-mvp.md`, six stages in the engine's direct Markdown
convention (`## Stage n — Title`). Validation:

```text
$ sparring check-plan docs/plans/socialcircle-mvp.md
docs/plans/socialcircle-mvp.md: 6 stage(s), read as markdown
  Stage 1 — Project Foundation
  Stage 2 — Registration and Authentication
  Stage 3 — Profile API and Social Connections
  Stage 4 — Angular Authentication and Profile UI
  Stage 5 — Member Directory and Social UI
  Stage 6 — End-to-End Verification and Demo Readiness
nothing was run or approved
```

`check-plan --json` reports `"valid": true, "kind": "markdown"` and `"mode":
"implementation"` for every stage (the Markdown convention cannot declare a
review-only stage; Stage 6 therefore runs with an implementation agent and
an independent review like every other stage).

The plan was committed on `main` before any run, as the engine requires
(`start-plan`/`run-plan` refuse a dirty tree, and the run digest binds the
stage sections so that an edit during the run pauses it).

## 4. Actual execution stages (pending)

To be filled from the run's artifacts. For each stage: stage id (`<run
key>-stage-<n>-<slug>`), entered at, cycles, final verdict, accepted
candidate SHA, duration from `sparring usage <stage-id>`.

| Stage | Stage id | Review cycles | Final verdict | Accepted SHA |
| --- | --- | --- | --- | --- |
| 1 — Project Foundation | pending | | | |
| 2 — Registration and Authentication | pending | | | |
| 3 — Profile API and Social Connections | pending | | | |
| 4 — Angular Authentication and Profile UI | pending | | | |
| 5 — Member Directory and Social UI | pending | | | |
| 6 — End-to-End Verification and Demo Readiness | pending | | | |

## 5. Implementation agent configuration (verified)

Provider `claude-cli` from `.sparring/project.toml`; model/effort provider
default (no user preference); permission mode `acceptEdits` (engine
default); project permissions from `.claude/settings.json`; instructions from
`CLAUDE.md` → `AGENTS.md`, plus the engine-assembled prompt (branch, stage
brief, `PROJECT.md`, artifact ownership, scope reminder). The exact prompt
of every turn is captured under `.sparring/stages/<id>/prompts/`.

## 6. Independent reviewer configuration (verified)

Provider `codex-cli`; model/effort provider default; OS-enforced read-only
sandbox; instructions from `AGENTS.md` (the "For the independent reviewer"
section) plus the engine's reviewer prompt, which requires one structured
JSON verdict (`READY` / `SEND_BACK` / `NEEDS_YOU` / `ESCALATE`), treats the
stage agent's test reports as unverified claims, and allows a `NEEDS_YOU`
only for checks a person must perform. Captured as
`prompts/000n-sparrer-*.md`.

## 7. Review outcomes (pending)

Per stage: the reviewer's `summary` and the substance of `findings` from
`sparring.md`, quoted or closely paraphrased, with the file path cited.
Record first-pass READY verdicts as such; do not editorialize.

## 8. Correction rounds (pending)

Per `SEND_BACK`: what the reviewer asked for, what the stage agent changed
(from the next `handoff.md` and the `git diff` between the two reviewed
candidates), and the re-review verdict.

## 9. Human checkpoints (pending)

Every `NEEDS_YOU` gate (category, checks, the evidence a person recorded in
`notes.md` under `## Human evidence`, the reviewer's response), every push
authorization (`awaiting.kind = push_authorization_required`, candidate SHA,
how it was answered), and every deferred check settled at plan completion
(`--deferred-result`).

## 10. Accepted commits (pending)

The chain of accepted candidate SHAs on the run branch, the merge into
`main` by `finish-run` (fast-forward or merge commit), and the `sparring
runs --json` record. Bootstrap commit on `main`: see section 2 (recorded
after the commit below).

## 11. Validation results (pending)

The final `make check`, `make e2e` and CI outcomes as actually observed,
with the commit they were run at. A check that was not run is listed as not
run, never as passed.

## 12. Known limitations

- Alpha tools: the single-stage loop and direct Markdown plan runs are the
  engine's stable core; plan intake is experimental and not used here.
- Metrics the tools do not expose (**unavailable**): monetary cost,
  wall-clock totals beyond per-turn durations in `sparring usage`, and any
  comparison against a non-sparring workflow (the engine's README states
  these are unbenchmarked).
- The reviewer cannot run the test suites (read-only sandbox); its READY
  verdicts rest on reading code, tests and diffs plus the stage agent's
  reported evidence, which it must label as claims.
- The CI workflow can only be observed green once a GitHub remote with
  Actions exists.
- The graphical VS Code walkthrough is documented from the extension's docs
  until it has been observed; see `vscode-workflow.md`.

## 13. Lessons learned (pending)

Filled in after the run.

## How to inspect the evidence yourself

All paths are inside the run's worktree (`../socialcircle-sparring-<run-key>/`)
while the run exists, and under `<git-common-dir>/agent-sparring/runs/<run-key>/`
after **Merge & clean up** archives them.

| Question | Where to look |
| --- | --- |
| What was the stage told? | `.sparring/stages/<id>/brief.md` (the plan section verbatim) and `prompts/0001-stage-original.md` (the full prompt) |
| What did the implementer claim? | `.sparring/stages/<id>/handoff.md` (`## Claims`, changed files, git context) |
| What did the reviewer decide and why? | `.sparring/stages/<id>/sparring.md` (`## Routing outcome`, `## Finding / discussion`, human gate JSON) |
| What changed between review rounds? | `git diff <candidate A> <candidate B>` on the run branch; the candidate SHAs are in `handoff.md` and `state.json` |
| Which exact commit was reviewed and accepted? | `.sparring/stages/<id>/state.json` (`candidate_sha`, `base_sha`, status `ACCEPTED`) |
| Was it accepted or refused, and when? | `.sparring/plans/<run-key>.json` and the `plan.*` lines in `activity.jsonl` |
| What did each turn cost in tokens and time? | `sparring usage <stage-id>` |
| What is the run's branch, worktree and merge target? | `sparring runs --json` |
| In VS Code | Overview → **Brief**, **Handoff**, **Sparring report**, **Diff**, **Log**; actor cards → **Show instructions**; **History / Runs…** |

Raw provider conversations, tokens and machine-specific paths are not
copied into this repository; this file summarizes and points to them.
