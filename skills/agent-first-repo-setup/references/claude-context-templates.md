# Claude Code On-Demand Rules and Skills Templates

Disclosed reference for Step 4 of [`agent-first-repo-setup`](../SKILL.md). Use these templates to configure `.claude/rules/` and `.claude/skills/` so context stays lean and loads only when relevant.

## Contents

- Path-scoped `.claude/rules/` mechanics and templates
- `.claude/skills/system-testing/SKILL.md` template
- `.claude/skills/domain-modeling/SKILL.md` template
- `.claude/skills/feature-development/SKILL.md` template

## Path-scoped `.claude/rules/` mechanics and templates

Claude Code loads files in `.claude/rules/*.md` unconditionally unless they declare a YAML frontmatter block with a `paths` field. `paths` is the only frontmatter field Claude Code reads in rule files. When `paths` is present, Claude Code loads the rule strictly on demand when reading, writing, or editing a file that matches one of the globs.

Every rule file generated in `.claude/rules/` must include `paths:` frontmatter so session startup context remains small.

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
- Write declarative scenarios that state observable business behavior rather than UI clicks, database tables, or internal class names.
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

- Write system tests in `tests/system/` as the primary verification method. Each system test exercises the application through its public entrypoint against the in-memory store and local fakes.
- Annotate or name each system test with the `@SPEC-NNN` identifier(s) it verifies so `scripts/check-traceability` can confirm coverage.
- Test observable behavior, not implementation details. Do not mock internal classes or domain services; fake only external process boundaries.
- Write unit tests in `tests/unit/` only for isolated, high-complexity domain logic with many algorithmic branches.
- Load `.claude/skills/system-testing/SKILL.md` when adding new test harnesses, fakes, or clearing Crapper (`CRAP < 10`), Dryer (`< 0.8%`), and Mutator gates.
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

- Keep `GLOSSARY.md` definitions to 1-2 sentences stating what the concept is in domain terms, with no implementation details, and list rejected synonyms under `_Avoid_`.
- Create an ADR in `docs/adr/NNNN-slug.md` only when a decision is (1) hard to reverse, (2) surprising without context, and (3) the result of a real trade-off.
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

# Scripts and Makefile Rules (Build the Lever)

- Keep top-level `Makefile` targets limited to `help`, `check`, `test`, `test-all`, and `build`. Expose filtering and scoping via variables (`MODULE=`, `SPEC=`, `FILTER=`, `SCOPE=`).
- Guardrail scripts in `scripts/` must be deterministic, exit non-zero on violations, and print the exact offending file or `@SPEC-NNN` ID along with the command or edit needed to fix it.
```

## `.claude/skills/system-testing/SKILL.md` template

Customize this skill with the exact database, fake strategy, test runner, and quality tools chosen during the Step 1 interview.

```markdown
---
name: system-testing
description: Guides writing and running fast system tests, in-memory fakes, and software quality signals (Dryer, Crapper, Mutator) in this repository. Use when writing or debugging tests, adding fakes for external dependencies, linking tests to @SPEC-NNN scenarios, or fixing quality gate failures.
---

# System Testing and Quality Signals

System tests in `tests/system/` are the primary verification mechanism for this repository. They prove that every Gherkin scenario in `features/` works end-to-end through the application's public boundary while remaining fast enough to run thousands of scenarios in seconds.

## System Test Architecture

- **Application boundary**: Drive the system through <HTTP handler / CLI entrypoint / message consumer / public API> in-process without network serialization overhead where possible.
- **Database strategy**: Use <in-memory / embedded single-node database chosen in Step 1>. Boot the schema once per test worker and reset state between tests using <transactions / fast table truncation / in-memory snapshot>.
- **External service fakes**: Fake external dependencies (<list external APIs/queues>) using deterministic in-memory fake implementations in `tests/system/fakes/`. Do not mock internal classes, repositories, or domain services.
- **Spec traceability**: Reference the covered `@SPEC-NNN` identifier in the test name, comment, or annotation so `./scripts/check-traceability` maps every scenario in `features/` to at least one system test.

## When to Write Unit Tests

Write unit tests in `tests/unit/` only as an exception for pure, self-contained domain logic with high branching complexity (for example parsers, pricing formulas, or state-machine transitions) where testing every edge case through the system boundary would be slow or repetitive.

## Running Tests and Quality Signals

```bash
make test                         # Fast loop: Gherkin check, traceability, Dryer, Crapper, and fast tests
make test SPEC=SPEC-001           # Run system tests covering SPEC-001
make test FILTER=<pattern>        # Run tests matching <pattern>
make test-all                     # Full loop: make test + Mutator across changed or all code
```

## Quality Signal Workflows (Crapper, Dryer, Mutator)

- **Crapper (`CRAP < 10`, Cognitive Complexity `< 15`)**: Enforced by `./scripts/check-quality --fast`. When a method exceeds the threshold, identify whether the driver is complexity (flatten nested conditionals or extract a cohesive domain method) or missing branch coverage (add a behavioral test).
- **Dryer (`Duplication < 0.8%`)**: Enforced by `./scripts/check-quality --fast` using `<jscpd or equivalent>`. When clones are detected, extract shared domain behavior to the module that owns the concept rather than creating generic `utils` classes.
- **Mutator (`make test-all`, `>= 80%` killed)**: Enforced by `./scripts/check-quality --all` using `<PIT / Stryker / mutmut / cargo-mutants / gremlins>`:
  1. Cover uncovered production branches.
  2. Kill surviving mutants by strengthening assertions on observable behavior.
  3. Delete dead code: if a mutant survives because the branch or condition is unreachable or redundant, delete the dead code rather than writing an artificial test.
```

## `.claude/skills/domain-modeling/SKILL.md` template

Adapted from Matt Pocock's `domain-modeling` approach for maintaining ubiquitous language and ADRs.

```markdown
---
name: domain-modeling
description: Maintains the repository's ubiquitous domain language in GLOSSARY.md and Architecture Decision Records in docs/adr/. Use when introducing or debating domain terms, updating GLOSSARY.md, or recording a non-obvious architectural decision in docs/adr/.
---

# Domain Modeling and Architecture Decisions

Keep the codebase, Gherkin features, and conversations aligned on one ubiquitous language in `GLOSSARY.md` (or `GLOSSARY-MAP.md` and per-module `GLOSSARY.md` files) and record non-obvious decisions in `docs/adr/`.

## Working with `GLOSSARY.md`

1. **Challenge conflicting terms**: When a prompt, feature spec, or code change uses a term that conflicts with `GLOSSARY.md` or uses a synonym listed under `_Avoid_`, call out the mismatch and align on the canonical term.
2. **Sharpen vague terms**: When an overloaded word appears (such as "account", "item", or "record"), ask which specific domain concept is meant and record the distinction.
3. **Update inline**: Update `GLOSSARY.md` immediately when a domain term is introduced or refined:
   - State what the concept is in 1-2 sentences without implementation details.
   - List rejected synonyms under `_Avoid:`.
   - Record relationships between concepts under `## Relationships`.

## Recording ADRs (`docs/adr/NNNN-slug.md`)

Create an ADR in `docs/adr/` when all three conditions hold:

1. **Hard to reverse**: Changing the decision later has a significant cost.
2. **Surprising without context**: A future engineer or agent would wonder why this approach was chosen.
3. **Real trade-off**: Genuine alternatives existed and one was chosen for specific reasons.

Format each ADR concisely:

```markdown
# NNNN: <Short title of the decision>

<1-3 sentences stating the context, the decision made, and why alternatives were rejected.>
```
```

## `.claude/skills/feature-development/SKILL.md` template

```markdown
---
name: feature-development
description: Implements new features or behavior changes spec-first using Gherkin scenarios in features/, fast system tests, and deterministic checks. Use when adding a feature, changing product behavior, or fixing a behavioral bug.
---

# Spec-First Feature Development

Follow the three-phase loop (**First Make It Work -> Then Make It Right -> Practice**) whenever adding or changing behavior in this repository.

## Step 1: Attack the premise and align domain language

Challenge unnecessary complexity in the request. Read `GLOSSARY.md` and relevant files in `docs/adr/`. Subtract obsolete shims or dead code before adding new code. If the change introduces a new domain concept or a non-obvious architectural trade-off, update `GLOSSARY.md` or add an ADR in `docs/adr/` using `.claude/skills/domain-modeling/SKILL.md`.

Completion criterion: all domain terms used by the feature exist in `GLOSSARY.md`, obsolete code is identified for removal, and any non-obvious trade-off is recorded in `docs/adr/`.

## Step 2: Sequence into a verifiable slice (`features/` + Red system test)

Add or update a Gherkin scenario in `features/<capability>.feature` (or `modules/<module>/features/<capability>.feature`) with a unique `@SPEC-NNN` tag. Write a system test in `tests/system/` referencing `@SPEC-NNN` (following `.claude/skills/system-testing/SKILL.md`). Run `make test SPEC=SPEC-NNN` and confirm the test fails for the expected behavioral reason.

Completion criterion: `./scripts/check-features` exits `0` and the `@SPEC-NNN` system test fails on the unimplemented behavior.

## Step 3: First make it work (Green)

Implement the behavior in `src/` following architecture discipline: encode domain invariants in types at the boundary, keep domain logic pure and I/O at the edges, make mutations idempotent, and separate state before serializing shared state. Update `docs/` (including `<!-- specs: SPEC-NNN -->` when documentation traceability is active).

Completion criterion: `make test SPEC=SPEC-NNN` passes.

## Step 4: Then make it right (Refactor & Quality Gates)

Refactor for clarity, fix root causes rather than symptoms, and run `make test` (and `make test-all` when touching complex logic) to clear the quality gates:
- **Crapper**: every method has `CRAP < 10` (and cognitive complexity `< 15`).
- **Dryer**: duplication is `< 0.8%`.
- **Mutator**: surviving mutants are killed with behavioral assertions, or dead code is deleted.

Completion criterion: `make test` exits `0` with zero traceability, Dryer, or Crapper violations.

## Step 5: Practice (Commit and clean up)

Commit the slice in small, ordered commits (separating structural refactoring commits from behavioral commits) and clean up any temporary worktrees.

Completion criterion: `git status` is clean and commits are ordered and atomic.
```
