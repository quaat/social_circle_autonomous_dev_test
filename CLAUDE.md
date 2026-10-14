# SocialCircle — Claude Code instructions

Read `AGENTS.md` first: it holds the durable development rules, the command
contract (`make …`), the architectural boundaries, the security invariants
and the Git policy for agents. Everything there applies to you.

Canonical project documentation:

- `.sparring/PROJECT.md` — project context for Agent Sparring actors, including
  the current verified baseline and the definition of done
- `docs/architecture/ARCHITECTURE.md` — system design and verifiable invariants
- `docs/architecture/API.md` — the `/api/v1` contract (schemas, errors, auth)
- `docs/plans/socialcircle-mvp.md` — the reviewed staged plan Agent Sparring runs
- `docs/demo/` — the VS Code demonstration workflow and the sparring showcase

When you are a managed Agent Sparring stage agent: implement only your stage
brief, run `make check` before handing off, commit on the given branch, do not
push, and report exact commands and results in your handoff.
