# Repository Layout and Evergreen File Templates

Disclosed reference for Step 3 of [`agent-first-repo-setup`](../SKILL.md). Adapt these templates to the language, build tool, and domain confirmed during Step 1.

## Contents

- Directory layouts (single-context and monorepo)
- `CLAUDE.md` template
- `GLOSSARY.md` and `GLOSSARY-MAP.md` templates
- `features/` seed Gherkin template
- `docs/README.md` and `docs/adr/` templates
- Parameterized `Makefile` template

## Directory layouts (single-context and monorepo)

### Single-context repository

```text
<repo-root>/
├── CLAUDE.md
├── GLOSSARY.md
├── Makefile
├── .claude/
│   ├── rules/
│   │   ├── features.md
│   │   ├── testing.md
│   │   ├── docs-and-adrs.md
│   │   └── scripts-and-build.md
│   └── skills/
│       ├── system-testing/SKILL.md
│       ├── domain-modeling/SKILL.md
│       └── feature-development/SKILL.md
├── features/
│   └── <capability>.feature
├── docs/
│   ├── README.md
│   └── adr/
│       └── 0001-agent-first-architecture.md
├── scripts/
│   ├── check-features
│   ├── check-traceability
│   └── check-quality
├── src/
└── tests/
    ├── system/
    └── unit/
```

### Multi-module monorepo

In a monorepo, every module owns a `features/` folder and a `GLOSSARY.md`. Root `GLOSSARY-MAP.md` links the bounded contexts, and `scripts/` can exist both at the root (repo-wide guardrails) and inside a module (module-specific checks).

```text
<repo-root>/
├── CLAUDE.md
├── GLOSSARY-MAP.md
├── Makefile
├── .claude/
│   ├── rules/
│   └── skills/
├── docs/
│   ├── README.md
│   └── adr/
│       └── 0001-agent-first-architecture.md
├── scripts/
│   ├── check-features
│   ├── check-traceability
│   └── check-quality
└── modules/
    ├── <module-a>/
    │   ├── GLOSSARY.md
    │   ├── features/
    │   │   └── <capability>.feature
    │   ├── docs/adr/
    │   ├── scripts/
    │   ├── src/
    │   └── tests/system/
    └── <module-b>/
        ├── GLOSSARY.md
        ├── features/
        ├── src/
        └── tests/system/
```

## `CLAUDE.md` template

Keep the generated `CLAUDE.md` under 120 lines. Detailed file rules live in `.claude/rules/` (loaded on demand by path) and procedural guides live in `.claude/skills/`.

```markdown
# <Project Name>

<1-2 sentences describing what the product, service, or library does.>

## Commands (`Makefile`)

Use the parameterized `Makefile` targets for all verification and build tasks:

```bash
make help                              # List targets and parameters
make check                             # Run Gherkin, traceability, and fast quality guardrails
make test                              # Run make check + fast system and unit tests
make test SPEC=SPEC-001                # Run system tests for one specification ID
make test MODULE=<name> FILTER=<pat>   # Scope tests to a module or test name pattern
make test-all                          # Run full verification including mutation testing
make build                             # Build artifacts
```

## Repository Structure and Concepts

- `GLOSSARY.md` (or `GLOSSARY-MAP.md` and `<module>/GLOSSARY.md`): Canonical domain language. Check this file before naming types, endpoints, or scenarios.
- `features/` (or `modules/<module>/features/`): Evergreen Gherkin specifications grouped by capability. Every requirement lives here with a unique `@SPEC-NNN` tag.
- `tests/system/`: Fast system tests that verify `@SPEC-NNN` scenarios against in-memory stores and local fakes. System tests are the primary test suite.
- `tests/unit/`: Unit tests reserved for isolated, high-complexity domain logic.
- `docs/`: Evergreen documentation. `docs/README.md` defines the documentation structure and `@SPEC-NNN` coverage annotations.
- `docs/adr/`: Architecture Decision Records (`NNNN-slug.md`). Every non-obvious, hard-to-reverse decision and its trade-offs live here so future work respects past choices.
- `scripts/`: Deterministic guardrail scripts executed by `make check`, `make test`, and `make test-all`.

## Engineering Principles

### 1. First Make It Work (Problem Solving & Architecture)

- **Attack the Premise & Subtract Before You Add**: Question requirements or abstractions that add accidental complexity. Delete dead code, unused indirection, and obsolete shims before adding new code.
- **Redesign From First Principles & Fix Root Causes**: When a design resists a change or a defect appears, fix the underlying domain model or boundary invariant rather than patching call sites.
- **Build the Lever**: Codify repeated checks, data setups, or conventions as deterministic scripts in `scripts/` wired into `Makefile` rather than adding prose warnings to `CLAUDE.md`.
- **Architecture Discipline**:
  - *Model the Domain & Type System Discipline*: Use exact terms from `GLOSSARY.md`. Encode domain invariants in types parsed at the boundary rather than passing raw primitives.
  - *Boundary Discipline*: Keep domain logic pure and free of I/O; isolate databases, HTTP clients, and queues behind adapters faked in system tests.
  - *Idempotency & State Isolation*: Make state-mutating operations idempotent and partition state before serializing access to shared state.

### 2. Then Make It Right (Verification & Quality Gates)

- **Sequence into Verifiable Units (TDD)**: Work in small vertical slices (`@SPEC-NNN` Gherkin scenario -> failing system test -> minimal implementation -> refactor).
- **Test Behavior, Not Implementation**: Verify observable outcomes through the public system boundary using in-memory stores and local fakes. Never mock internal classes.
- **Clear the Quality Gates**:
  - **Crapper (`CRAP < 10`)**: Keep method change-risk below 10 (and cognitive complexity `< 15`) by flattening nested control flow or covering branches.
  - **Dryer (`Duplication < 0.8%`)**: Keep clone density below 0.8%. Extract shared domain rules to their owning module.
  - **Mutator (`make test-all`)**: Cover uncovered branches, strengthen behavioral assertions to kill surviving mutants, and delete code whose mutants survive because the branch is dead or redundant.

### 3. Practice (Context & Execution Hygiene)

- **Guard the Context Window**: Delegate broad codebase searches, log analysis, and noisy tool runs to fresh subagents. Rely on path-scoped `.claude/rules/` and on-demand `.claude/skills/`.
- **Protect Evergreen Assets**: Files in `features/`, `docs/`, `docs/adr/`, and `GLOSSARY.md` are permanent assets. Never link from evergreen files to transient plans, scratch notes, or task files.
- **Small Ordered Commits & Worktree Cleanup**: Commit each verifiable slice in small, ordered commits (separating structural refactoring from behavioral changes) and remove temporary git worktrees when finished.
```

## `GLOSSARY.md` and `GLOSSARY-MAP.md` templates

Follow the domain-modeling convention: define what each domain concept is in 1 to 2 sentences, exclude implementation details, and list rejected synonyms under `_Avoid_`.

### `GLOSSARY.md` (single-context or per-module)

```markdown
# <Context or Project Name> Glossary

<1-2 sentence description of this bounded context and why it exists.>

## Language

**<Term 1>**:
<1-2 sentence definition of the concept in domain terms, without implementation details.>
_Avoid_: <synonym 1>, <synonym 2>

**<Term 2>**:
<1-2 sentence definition of the concept.>
_Avoid_: <synonym 1>

## Relationships

- A **<Term 1>** contains one or more **<Term 2>** entries.
```

### `GLOSSARY-MAP.md` (root of a multi-module monorepo)

```markdown
# Glossary Map

## Contexts

- [<Module A>](./modules/<module-a>/GLOSSARY.md): <1-line responsibility>
- [<Module B>](./modules/<module-b>/GLOSSARY.md): <1-line responsibility>

## Relationships

- **<Module A> -> <Module B>**: <How the contexts interact or share identifiers>
```

## `features/` seed Gherkin template

Group related scenarios into `<capability>.feature` files under `features/` (or `modules/<module>/features/`). Tag every `Scenario` or `Scenario Outline` with a unique `@SPEC-NNN` identifier.

```gherkin
Feature: <Capability Name>
  As a <actor from GLOSSARY.md>
  I want to <goal>
  So that <business outcome>

  @SPEC-001
  Scenario: <Observable behavior using GLOSSARY.md terms>
    Given <initial domain state>
    When <action occurs>
    Then <observable outcome>
```

## `docs/README.md` and `docs/adr/` templates

### `docs/README.md`

```markdown
# Documentation Guide

This directory holds evergreen documentation for `<Project Name>`.

## Structure

- `docs/adr/`: Architecture Decision Records (`NNNN-slug.md`) explaining non-obvious technical and domain decisions.
- `docs/<capability>.md`: Feature and architecture documentation written in clear technical English.

## Spec Traceability Annotations

Every documented capability lists the `@SPEC-NNN` identifiers it covers using an HTML comment:

```markdown
<!-- specs: SPEC-001 -->
```

`scripts/check-traceability` verifies that every `@SPEC-NNN` defined in `features/` is covered by a system test and (when `REQUIRE_DOC_TRACEABILITY=1` is set) documented in `docs/`.

## Evergreen Rule

Files in `docs/` are permanent project assets. Do not link to temporary plans, scratch notes, or transient task files.
```

### `docs/adr/0001-agent-first-architecture.md`

```markdown
# 0001: Agent-First Repository Architecture and System-Test Harness

We structure this repository around executable Gherkin specifications (`features/`), a canonical domain glossary (`GLOSSARY.md`), deterministic guardrail scripts (`scripts/`), and fast system tests (`tests/system/`) backed by <in-memory DB / local fakes chosen in Step 1>. We enforce Dryer (`duplication < 0.8%`), Crapper (`CRAP < 10`), and Mutator thresholds through `make test` and `make test-all` so humans and AI agents get immediate, deterministic feedback without relying on fragile mocks or prose reminders.
```

## Parameterized `Makefile` template

Keep top-level targets to five commands (`help`, `check`, `test`, `test-all`, `build`) and expose knobs through variables (`MODULE`, `SPEC`, `FILTER`, `SCOPE`).

```makefile
.PHONY: help check test test-all build

MODULE ?=
SPEC   ?=
FILTER ?=
SCOPE  ?= changed

help: ## Show available commands and parameters
	@printf "Targets:\n"
	@printf "  make check                            Run Gherkin, traceability, and fast quality guardrails\n"
	@printf "  make test [MODULE=] [SPEC=] [FILTER=] Run check + fast test suite and quality gates\n"
	@printf "  make test-all [MODULE=] [SCOPE=]      Run full verification including mutation tests\n"
	@printf "  make build [MODULE=]                  Build project artifacts\n"

check: ## Run deterministic guardrails
	./scripts/check-features $(if $(MODULE),--module $(MODULE),)
	./scripts/check-traceability $(if $(MODULE),--module $(MODULE),)
	./scripts/check-quality --fast $(if $(MODULE),--module $(MODULE),) --scope $(SCOPE)

test: check ## Run fast checks and system tests
	# Replace with the stack test runner command parameterized by MODULE, SPEC, and FILTER
	<test-runner-command>

test-all: test ## Run all tests plus slow quality signals (mutation testing)
	./scripts/check-quality --all $(if $(MODULE),--module $(MODULE),) --scope $(SCOPE)

build: ## Build the project
	<build-command>
```
