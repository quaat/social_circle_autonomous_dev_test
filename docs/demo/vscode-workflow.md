# Running the SocialCircle plan from VS Code

This guide walks through the Agent Sparring VS Code extension as the
demonstration cockpit. The **engine** (`sparring` CLI) owns execution,
verification and acceptance; the **extension** only presents engine state and
invokes engine commands. Command names below are the extension's actual
command-palette titles (`docs/commands.md` in the extension repository,
revision e4bb264).

> Verification status: the engine, the Claude Code plugin and the extension
> (`agent-sparring-vscode-0.1.0.vsix`, built from revision e4bb264) were
> installed and verified from the CLI during bootstrap. **The graphical
> workflow below has not yet been observed in a live run.** Steps are taken
> from the extension's documentation; `docs/demo/sparring-showcase.md` records
> what was actually seen once the run happens.

## Prerequisites (verified during bootstrap)

| Component | Verified state |
| --- | --- |
| `sparring` engine | `uv tool install --editable ../agent-sparring` → `/home/<you>/.local/bin/sparring`, revision c4fb297 |
| Claude Code CLI | 2.1.299, signed in (`claude auth status`) |
| Codex CLI | 0.158.0, signed in (`codex login status` → "Logged in using ChatGPT") |
| Claude Code plugin | `claude plugin marketplace add sigmundas/agent-sparring` then `claude plugin install agent-sparring@agent-sparring` (0.1.0, enabled). The skills `/agent-sparring:sparring-setup`, `/agent-sparring:sparring-plan`, `/agent-sparring:sparring-run` become available in a **new** Claude Code session, not the one that installed the plugin. |
| VS Code | 1.139.0 with `sintef.agent-sparring-vscode@0.1.0` installed via `code --install-extension agent-sparring-vscode-0.1.0.vsix` |
| Repository | `sparring check-config` exits 0; plan validated with `sparring check-plan docs/plans/socialcircle-mvp.md`; bootstrap committed on `main`; a writable `origin` remote (required for acceptance) |

If VS Code was started from a launcher whose environment lacks
`~/.local/bin`, the extension may not find `sparring`. Either start VS Code
from a shell where `sparring --version` works (`code .` inside the
repository) or run **Agent Sparring: Choose sparring Executable…** and pick
`~/.local/bin/sparring`; that stores `agentSparring.executable` in your
settings. The same applies to `claude` and `codex` for the provider turns:
they are resolved from the shell that runs the engine.

## The walkthrough

1. **Open the repository.** `code /path/to/socialcircle` (the primary
   checkout on `main`). Accept the recommended extensions prompt if shown.
2. **Agent Sparring: Open Project Settings.** Opens `.sparring/project.toml`.
   It already exists (created by `sparring init-config`), so no "Create
   project settings" is needed. It declares the providers only.
3. **Agent Sparring: Open Overview.** The Run Overview panel opens in the
   editor area. With no run yet it shows the repository and the two actor
   cards.
4. **Confirm the Stage agent is Claude Code.** The **Stage agent** card reads
   provider `claude-cli`; model and effort read **Provider default** unless
   you set a preference. The card's values come from `sparring show-config
   --json`, never from reading the TOML directly.
5. **Confirm the Sparrer is Codex.** The **Sparrer** card reads `codex-cli`.
   Choosing a model or effort on either card runs `sparring set-config …`,
   which writes your user preference file
   (`~/.config/agent-sparring/config.toml`), never the repository. Provider
   defaults are fine for this demonstration.
6. **Open the plan.** Open `docs/plans/socialcircle-mvp.md`. It has six
   `## Stage n — Title` sections; this is the staged Markdown convention
   the engine runs directly (no intake turn).
7. **Agent Sparring: Run Plan.** Pick the plan from the list (an open
   Markdown editor with `## Stage` sections is used directly). The engine
   classifies it with `sparring check-plan --json` first.
8. **Choose "Run in its own workspace (recommended)".** The engine will
   create a Git worktree `../socialcircle-sparring-<run-key>` on a new branch
   `sparring/socialcircle-mvp-<suffix>` from `main`. Your checkout is not
   switched or modified.
9. **Confirm the execution settings.** The confirmation names the plan, the
   target branch and whether the run may push. Two buttons: start **without**
   push authorization (the engine will pause at each verified candidate and
   ask you to **Allow push**), or start with **auto-push for this run**
   (`--allow-push-for-run`: the engine itself pushes each verified candidate
   to `origin/<run branch>` with an ordinary non-force push). Pushing is a
   genuine human checkpoint in this project (`AGENTS.md` forbids agents from
   pushing); pick per-candidate authorization if you want to see the gate,
   auto-push if you want the run unattended. Either way, this launches
   `sparring run-plan docs/plans/socialcircle-mvp.md --managed --target-branch main [--allow-push-for-run]`
   in a tracked terminal.
10. **Start execution.** The Overview follows the run by its run key as soon
    as `sparring runs --json` lists it. The journey strip shows six stages;
    the current stage card shows **Working** while a provider turn runs.
11. **Observe stage implementation.** The **Stage agent** card shows
    activity from `.sparring/stages/<id>/activity.jsonl` (files edited,
    commands run, context-window occupancy as the provider reports it).
    **Show instructions** on the card opens the exact prompt the engine
    handed to Claude (`prompts/0001-stage-original.md`): the branch
    constraint, the stage brief, `PROJECT.md`, the artifact-ownership and
    scope-reminder sections. **Brief**, **Handoff**, **Diff** and **Log**
    buttons open the engine's artifacts for the stage.
12. **Inspect independent reviewer findings.** When the implementation turn
    ends, the **Sparrer** card shows the review turn. Its **Show
    instructions** is `prompts/000n-sparrer-original.md` (or `-resume`).
    The **Sparring report** button opens `sparring.md`: `## Routing outcome`
    (the verdict), `## Finding / discussion` (what Codex inspected and
    found), and the structured `<!-- human-gate:v1 -->` JSON when the verdict
    is `NEEDS_YOU`.
13. **Observe any actual SEND_BACK corrections.** A `SEND_BACK` shows as
    **Changes requested — The independent reviewer found something to fix.
    Work will continue automatically.** The same Claude session resumes with
    the findings embedded (`prompts/000n-stage-resume.md`), produces a new
    handoff, and the same Codex session re-reviews. The loop cycle counter
    on the stage card increments; the engine stops after 5 cycles
    (`--max-send-back-cycles`). Nothing here is staged for effect: whether a
    stage passes first time or needs corrections is whatever the reviewer
    decides.
14. **Respond to genuine human checkpoints.** A `NEEDS_YOU` verdict shows
    **Needs you** with a **Manual check required** panel listing each check's
    instruction and pass criteria verbatim from the gate. Do the check, record
    **Pass**, **Fail** or **Can't test** with your observations, optionally
    add **Additional findings or instructions**, then press **Submit result
    and continue**. That appends your words under `## Human evidence` in the
    stage's `notes.md` and runs `sparring resume-plan --run-key <key>
    --evidence …`; the **same reviewer session** judges the evidence. A
    **Push authorization required** panel is a permission, not a check:
    **Allow push** runs `resume-plan --allow-push-candidate <sha>` for exactly
    that commit (toggle "Auto-push future accepted candidates in this run" to
    stop being asked). Pauses caused by a provider failure show **Retry** or
    **Start fresh …** cards.
15. **Inspect accepted stages and run history.** An accepted stage shows
    **Accepted — Stage complete.**; its `state.json` records the candidate
    SHA. The journey strip marks accepted stages; the next one starts
    automatically with fresh sessions. **History / Runs…** (and the Runs
    sidebar) list every run and let you pin one to inspect; **Follow active
    repository** returns to the live one. `sparring usage <stage-id>` in a
    terminal prints what each turn ran with and the tokens the providers
    reported.
16. **Complete the run and use Merge & clean up.** When the run reports
    **Complete** (every stage accepted and no deferred check still owed; a
    deferred check pauses the run at the end until you answer it), the
    Overview offers **Merge & clean up** (also **Agent Sparring: Merge &
    Clean Up Run**). It first runs `sparring finish-run --run-key <key>
    --dry-run --json` (read-only); if the engine says the run is not
    eligible, each failing check is shown in plain words and nothing happens.
    Otherwise a confirmation states what is merged into `main` (fast-forward,
    or a merge commit if `main` moved and you allow it), which ignored files
    are deleted with the workspace, and that the remote run branch is kept.
    **Merge, push main & clean up** adds `--push-target`. Confirm, and the
    engine merges, archives the run's `.sparring/` state to
    `<git-common-dir>/agent-sparring/runs/<run-key>/`, removes the worktree
    and deletes the local run branch. The cockpit then follows the primary
    checkout.

## Authoritative state versus what the extension shows

| What you see | Where the truth is | Notes |
| --- | --- | --- |
| Running / Paused / Needs you / Complete | `.sparring/plans/<run-key>.json` (inside the run's worktree) | The extension reads it; it never writes it |
| Working / Changes requested / Review complete / Accepted | `.sparring/stages/<id>/sparring.md` (`## Routing outcome`) and `state.json` | A stage is accepted only when `state.json` says so after `freeze-candidate` + `accept-candidate` succeeded at a pushed SHA |
| Manual check panel | the `<!-- human-gate:v1 -->` JSON in `sparring.md` | Laid out verbatim; nothing inferred from prose |
| Which runs exist, where their worktrees are | `sparring runs --json` | Folder and branch names never make a worktree a run's |
| Ready to merge | `sparring finish-run --dry-run --json` (seconds old) | Never inferred from "complete" |
| Agent model/effort | `sparring show-config --json` | The extension does not parse TOML |

The extension is a view. A progress bar that looks finished, a terminal that
printed "READY", or an activity stream that went quiet are **not** acceptance.
Acceptance is the engine's recorded `ACCEPTED` state at a pushed commit SHA,
and `docs/demo/sparring-showcase.md` cites those SHAs.

## CLI equivalents

```sh
sparring run-plan docs/plans/socialcircle-mvp.md --managed --target-branch main [--allow-push-for-run]
sparring runs --json                                   # run key, worktree, branch, status
sparring resume-plan --run-key <key> [--evidence "…"] [--allow-push-candidate <sha>] \
                     [--deferred-result <check>=pass|fail|blocked[=note]]
sparring usage <stage-id>                              # turns, models, tokens
sparring finish-run --run-key <key> --dry-run --json   # eligibility
sparring finish-run --run-key <key> [--push-target] [--allow-merge-commit]
```

Prefer the extension for the live demonstration; use the CLI to inspect or
to continue a run from a terminal.
