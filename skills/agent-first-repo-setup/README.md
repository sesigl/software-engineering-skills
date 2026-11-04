# agent-first-repo-setup

Interviews you and scaffolds a new or empty Git repository so humans and coding agents can build, verify, and change software with fast feedback and deterministic guardrails. The skill targets Claude Code by default. For other harnesses, such as Codex, Cursor, GitHub Copilot, or Gemini CLI, it researches their current conventions and adapts the agent context.

## Why

An agent works only as well as the repository lets it check its own work. Without a domain glossary, executable specifications, and fast system tests, the agent guesses names, writes tests that check implementation details, and reports "done" without proof. Long always-on instruction files also fill the context window with rules that do not apply to the current task. This skill sets up the repository so that each rule loads only when it applies, and so that `make test` gives a deterministic yes or no.

## How It Works

```text
Step 1: Interview           Reads existing files and reference docs first, infers defaults,
        │                   and asks only open questions (2–4 per round): domain + @SPEC-001
        │                   increment, system shape + architecture contracts, stack + fast
        │                   test boundary + quality gates, agent harnesses + docs traceability.
        ▼
Step 2: Blueprint           Shows the directory tree, architecture contracts, Makefile targets,
        │                   guardrail scripts, and agent context. Waits for approval.
        ▼
Step 3: Foundations         git init, instruction file (CLAUDE.md, or AGENTS.md plus adapters),
        │                   GLOSSARY.md (or GLOSSARY-MAP.md), features/ with @SPEC-001,
        │                   docs/README.md, docs/adr/0001, parameterized Makefile.
        ▼
Step 4: Agent context       Path-scoped rules and on-demand skills (system-testing,
        │                   domain-modeling, feature-development, plus optional read-only
        │                   system skills), rendered only for the selected harnesses.
        ▼
Step 5: Guardrails          scripts/check-features, check-traceability, check-quality
                            (Dryer < 0.8%, Crapper CRAP < 10, Mutator >= 80% on make test-all),
                            check-agent-context for two or more harnesses. Probes architecture
                            contracts and runs make test until it exits 0.
```

The generated repository follows three principles: **First Make It Work** (question requirements, fix root causes, automate checks in scripts), **Then Make It Right** (system-test-first against plain data or in-memory stores, quality gates), and **Practice** (small context, evergreen ADRs, small ordered commits).

## Example Prompts

```text
/agent-first-repo-setup billing-api
```

```text
Set up this empty folder as an agent-first TypeScript repository for a subscription billing API.
```

```text
Bootstrap a monorepo with the modules ordering and inventory. Claude Code and Codex will both work in it.
```

## Evals

Each case runs with and without the plugin. The cases are in [`evals/agent-first-repo-setup/`](../../evals/agent-first-repo-setup/), and the portable copy is in [`evals/evals.json`](evals/evals.json). The scaffold cases write files and run `make` in a sandbox without network access.

| Case | What it checks | Delta |
| :--- | :--- | ---: |
| `starts-with-focused-interview-and-recommended-defaults` | Asks about harnesses, domain terms, fast test harness, and quality gates with defaults, and writes no files before confirmation. | +0.39 |
| `scaffolds-single-context-repo-with-path-scoped-rules-and-working-guardrails` | Claude Code only: creates the full blueprint with `paths:` rules and tailored skills, no files for other harnesses, and a final `make test` that exits 0. | +0.83 |
| `scaffolds-monorepo-with-per-module-features-and-glossary-map` | Creates `GLOSSARY-MAP.md`, per-module glossaries and features, and `MODULE=` support, and `check-features` covers both modules. | +0.50 |
| `adapts-agent-context-to-claude-code-codex-and-cursor` | Uses given harness findings: `AGENTS.md` as the canonical file, `CLAUDE.md` imports it, nested `AGENTS.md` rules, shared `.agents/skills/`, and `make check` runs `check-agent-context`. | Not run yet |

The per-assertion pass rates and the findings are in [`evals/RESULTS.md`](../../evals/RESULTS.md#agent-first-repo-setup).
