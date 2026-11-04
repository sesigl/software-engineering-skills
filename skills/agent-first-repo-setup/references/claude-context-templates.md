# Claude Code On-Demand Rules and Skills Templates

Disclosed reference for Step 4 of [`agent-first-repo-setup`](../SKILL.md). Use these templates to configure `.claude/rules/` and `.claude/skills/` so context stays lean and loads only when relevant.

## Contents

- Path-scoped `.claude/rules/` mechanics and templates
- `.claude/skills/system-testing/SKILL.md` template
- `.claude/skills/domain-modeling/SKILL.md` template
- `.claude/skills/feature-development/SKILL.md` template
- Optional read-only external-system skill and guarded query helper

## Path-scoped `.claude/rules/` mechanics and templates

Claude Code loads files in `.claude/rules/*.md` unconditionally unless they declare a YAML frontmatter block with a `paths` field. `paths` is the only frontmatter field Claude Code reads in rule files. When `paths` is present, Claude Code loads the rule strictly on demand when reading, writing, or editing a file that matches one of the globs.

**Gotcha**: Every `.claude/rules/*.md` file must start at line 1 with `---`. Copy only the inner YAML frontmatter and rule body from the fenced templates below (leaving out the outer ```` ```markdown ```` fence), because a leading code fence prevents Claude Code from parsing the `paths:` frontmatter. `scripts/check-traceability` verifies that every rule file starts with `---`.

### `.claude/rules/architecture.md`

Scope this rule to the production source tree and tailor the bullets to the architecture contracts confirmed in Step 1.

```markdown
---
paths:
  - "src/**"
  - "modules/*/src/**"
---

# Architecture and Production Code Rules

- Keep `core/` (and pipeline `transform` modules) pure: no I/O, network, process, clock, randomness, or storage imports. `make check` enforces these contracts.
- Parse and validate raw inputs at the boundary. Inside the core, pass domain value objects and typed IDs from `GLOSSARY.md`.
- Add shared code to `core/` only when two or more slices or jobs need it.
```

### `.claude/rules/features.md`

```markdown
---
paths:
  - "features/**/*.feature"
  - "**/features/**/*.feature"
---

# Feature Specification Rules (Gherkin)

- Group related scenarios by business capability in `features/<capability>.feature` (or `modules/<module>/features/<capability>.feature`).
- Tag every `Scenario` and `Scenario Outline` with a unique `@SPEC-NNN` identifier (for example `@SPEC-001`).
- Use exact domain terms from `GLOSSARY.md` (and exclude synonyms listed under `_Avoid_`).
- Write declarative scenarios that state observable business behavior with real domain ID formats rather than UI clicks, database tables, or internal class names.
- After editing any `.feature` file, run `make check` to validate Gherkin syntax and `@SPEC-NNN` traceability.
```

### `.claude/rules/testing.md`

Adjust the `paths` globs to match the language's test file naming convention.

```markdown
---
paths:
  - "tests/**"
  - "**/tests/**"
  - "**/*Test*"
  - "**/*Spec*"
  - "**/*IT*"
  - "**/*.test.*"
  - "**/*.spec.*"
---

# Testing Rules (Test Behavior, Not Implementation)

- Write system tests in `tests/system/` as the primary verification method. Each system test exercises the public boundary with plain input data (for pure transforms) or in-memory stores and local fakes (for stateful services).
- Name or annotate each system test with the `@SPEC-NNN` identifier it verifies (for example `test_spec_001_<behavior>`) so `make test SPEC=SPEC-001` and `scripts/check-traceability` work deterministically.
- Test observable behavior, not implementation details. Do not mock internal classes or domain services.
- Write unit tests in `tests/unit/` only for isolated, high-complexity domain logic with many algorithmic branches.
- Load `.claude/skills/system-testing/SKILL.md` when adding test harnesses or clearing Crapper (`CRAP < 10`), Dryer (`< 0.8%`), and Mutator gates.
```

### `.claude/rules/docs-and-adrs.md`

```markdown
---
paths:
  - "docs/**/*.md"
  - "**/docs/**/*.md"
  - "GLOSSARY*.md"
  - "**/GLOSSARY.md"
---

# Documentation, Glossary, and ADR Rules

- Keep `GLOSSARY.md` definitions to 1-2 sentences stating what the concept is in domain terms, with no implementation details, and list rejected synonyms under `_Avoid_`. When renaming a term, move the old term to `_Avoid_`.
- Create an ADR in `docs/adr/NNNN-slug.md` only when a decision is (1) hard to reverse, (2) surprising without context, and (3) the result of a real trade-off.
- When a later ADR changes an earlier decision, add `Amended by [NNNN](NNNN-slug.md)` to the earlier ADR rather than rewriting history.
- Annotate feature documentation in `docs/` with covered spec IDs (`<!-- specs: SPEC-001 -->`) when documentation traceability is enabled.
- Never reference transient scratch, plan, or task files from `docs/`, `GLOSSARY.md`, or `features/`.
```

### `.claude/rules/scripts-and-build.md`

```markdown
---
paths:
  - "Makefile"
  - "scripts/**"
  - "**/scripts/**"
---

# Scripts and Makefile Rules

- Keep top-level `Makefile` targets limited to `help`, `check`, `test`, `test-all`, and `build`. Expose filtering and scoping via variables (`MODULE=`, `SPEC=`, `FILTER=`, `SCOPE=`).
- Guardrail scripts in `scripts/` must be deterministic, exit non-zero on violations, and print the exact offending file or `@SPEC-NNN` ID along with the command or edit needed to fix it.
```

## `.claude/skills/system-testing/SKILL.md` template

Customize this skill with the exact system shape, test boundary, test runner, and quality tools chosen during Step 1.

```markdown
---
name: system-testing
description: Guides writing and running fast system tests and software quality signals (Dryer, Crapper, Mutator) in this repository. Use when writing or debugging tests, linking tests to @SPEC-NNN scenarios, or fixing quality gate failures.
---

# System Testing and Quality Signals

System tests in `tests/system/` are the primary verification mechanism for this repository. They prove that every Gherkin scenario in `features/` works through the public boundary in milliseconds.

## System Test Architecture

- **Public boundary**: Drive `<transform function / HTTP handler / CLI entrypoint / public API>` in-process.
- **State and dependencies**: `<Pass plain in-memory input records and assert on returned output records / Use in-memory SQLite/PGlite/H2 and local fakes at external boundaries>`. Do not mock internal classes or domain services.
- **Spec traceability and filtering**: Name each test `test_spec_<nnn>_<behavior>` and reference `@SPEC-NNN` so `scripts/check-traceability` verifies coverage and `make test SPEC=SPEC-001` runs that scenario alone.

## When to Write Unit Tests

Write unit tests in `tests/unit/` only as an exception for pure, self-contained domain logic with high branching complexity (for example parsers, normalization rules, or pricing formulas) where testing every edge case through the system boundary would be repetitive.

## Running Tests and Quality Signals

```bash
make test                         # Fast loop: check + all tests + Dryer + Crapper
make test SPEC=SPEC-001           # Run only the system test for SPEC-001 (skips Dryer/Crapper)
make test FILTER=<pattern>        # Run tests matching <pattern>
make test SCOPE=unit              # Run only tests/unit (or SCOPE=system)
make test-all                     # Full loop: make test + Mutator (>= 80%)
```

## Quality Signal Workflows (Crapper, Dryer, Mutator)

- **Crapper (`CRAP < 10`, complexity `< 15`)**: Enforced by `./scripts/check-quality --fast` on full test runs. When a function exceeds the threshold, flatten nested conditionals or add a behavioral test covering the untested branches.
- **Dryer (`Duplication < 0.8%`)**: Enforced by `./scripts/check-quality --fast`. Extract shared domain behavior to the module that owns the concept rather than creating generic `utils` files.
- **Mutator (`make test-all`, `>= 80%` killed)**: Enforced by `./scripts/check-quality --all`:
  1. Cover uncovered production branches.
  2. Kill surviving mutants by strengthening assertions on observable behavior.
  3. Delete dead code: if a mutant survives because a branch is unreachable or redundant, delete the code rather than writing an artificial test.
```

## `.claude/skills/domain-modeling/SKILL.md` template

```markdown
---
name: domain-modeling
description: Maintains the repository's ubiquitous domain language in GLOSSARY.md and Architecture Decision Records in docs/adr/. Use when introducing, renaming, or debating domain terms, updating GLOSSARY.md, or recording or amending an architectural decision in docs/adr/.
---

# Domain Modeling and Architecture Decisions

Keep the codebase, Gherkin features, and conversations aligned on one ubiquitous language in `GLOSSARY.md` (or `GLOSSARY-MAP.md` and per-module `GLOSSARY.md` files) and record non-obvious decisions in `docs/adr/`.

## Working with `GLOSSARY.md`

1. **Challenge conflicting terms**: When a prompt, feature spec, or code change uses a term that conflicts with `GLOSSARY.md` or uses a synonym listed under `_Avoid_`, call out the mismatch and align on the canonical term.
2. **Sharpen vague terms**: When an overloaded word appears (such as "account", "item", or "record"), ask which specific domain concept is meant and record the distinction.
3. **Update inline**: Update `GLOSSARY.md` immediately when a domain term is introduced or renamed:
   - State what the concept is in 1-2 sentences without implementation details.
   - List rejected synonyms (including any old term that was renamed) under `_Avoid_`.
   - Record relationships between concepts under `## Relationships`.

## Recording and Amending ADRs (`docs/adr/NNNN-slug.md`)

Create an ADR in `docs/adr/` when all three conditions hold:

1. **Hard to reverse**: Changing the decision later has a significant cost.
2. **Surprising without context**: A future engineer or agent would wonder why this approach was chosen.
3. **Real trade-off**: Genuine alternatives existed and one was chosen for specific reasons.

When a new ADR supersedes or modifies part of an earlier ADR, keep the earlier ADR intact and add `Amended by [NNNN](NNNN-slug.md): <1-line summary>` to its Decision section.
```

## `.claude/skills/feature-development/SKILL.md` template

```markdown
---
name: feature-development
description: Implements new features or behavior changes spec-first using Gherkin scenarios in features/, fast system tests, and deterministic checks. Use when adding a feature, changing product behavior, or fixing a behavioral bug.
---

# Spec-First Feature Development

Follow the three-phase loop (**First Make It Work -> Then Make It Right -> Practice**) whenever adding or changing behavior in this repository.

## Step 1: Check requirements and align domain language

Challenge unnecessary complexity in the request. Read `GLOSSARY.md` and relevant files in `docs/adr/`. Remove obsolete shims or dead code before adding new code. If the change introduces or renames a domain concept or makes a non-obvious architectural trade-off, update `GLOSSARY.md` or add an ADR in `docs/adr/` using `.claude/skills/domain-modeling/SKILL.md`.

Completion criterion: all domain terms used by the feature exist in `GLOSSARY.md`, obsolete code is identified for removal, and any non-obvious trade-off is recorded in `docs/adr/`.

## Step 2: Sequence into a verifiable slice (`features/` + Red system test)

Add or update a Gherkin scenario in `features/<capability>.feature` (or `modules/<module>/features/<capability>.feature`) with a unique `@SPEC-NNN` tag. Write a system test in `tests/system/` named `test_spec_<nnn>_<behavior>` referencing `@SPEC-NNN` (following `.claude/skills/system-testing/SKILL.md`). Run `make test SPEC=SPEC-NNN` and confirm the test fails for the expected behavioral reason.

Completion criterion: `./scripts/check-features` exits `0` and `make test SPEC=SPEC-NNN` fails on the unimplemented behavior.

## Step 3: First make it work (Green)

Implement the behavior in `src/` following architecture discipline: encode domain invariants in types at the boundary, keep core logic pure and I/O at the edges, and satisfy all architecture contracts. Update `docs/` when documentation traceability is active.

Completion criterion: `make test SPEC=SPEC-NNN` passes.

## Step 4: Then make it right (Refactor & Quality Gates)

Refactor for clarity, fix root causes rather than symptoms, and run `make test` (and `make test-all` when touching complex logic) to clear the quality gates:
- **Crapper**: every function/method has `CRAP < 10` and complexity `< 15`.
- **Dryer**: duplication is `< 0.8%`.
- **Mutator**: surviving mutants are killed with behavioral assertions, or dead code is deleted.

Completion criterion: `make test` exits `0` with zero architecture, traceability, Dryer, or Crapper violations.

## Step 5: Practice (Commit and clean up)

Commit the slice in small, ordered commits (separating structural refactoring commits from behavioral commits) and clean up any temporary worktrees.

Completion criterion: `git status` is clean and commits are ordered and atomic.
```

## Optional read-only external-system skill and guarded query helper

Generate this only when Step 1 identifies live external systems (such as a data warehouse or search index) that agents inspect for domain discovery.

1. **Guarded read-only SQL/query helper (`scripts/dbq.py` or equivalent)**: When agents run SQL against a warehouse, wrap the CLI in a small script with unit tests in `tests/unit/` that rejects multiple statements (`;` inside the body), requires the statement to start with `SELECT`, `WITH`, `SHOW`, `DESCRIBE`, or `EXPLAIN`, and rejects write keywords (`INSERT`, `UPDATE`, `DELETE`, `MERGE`, `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `GRANT`, `REVOKE`, `COPY`, `OPTIMIZE`, `VACUUM`).
2. **Per-system inspection skill (`.claude/skills/<system>-inspection/SKILL.md`)**: Document the read-only command, required partition filters and `LIMIT`, and the evergreen `docs/<system>.md` file where verified facts belong.
