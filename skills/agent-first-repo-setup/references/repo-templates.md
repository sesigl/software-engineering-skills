# Repository Layout and Evergreen File Templates

Disclosed reference for Step 3 of [`agent-first-repo-setup`](../SKILL.md). Adapt these templates to the system shape, language, build tool, and domain confirmed during Step 1.

## Contents

- Architecture by system shape
- Directory layouts (single-context and monorepo)
- `CLAUDE.md` template
- `GLOSSARY.md` and `GLOSSARY-MAP.md` templates
- `features/` seed Gherkin template
- `docs/README.md` and `docs/adr/` templates
- Parameterized `Makefile` template

## Architecture by system shape

Select the package layout and test boundary from the system shape instead of defaulting to hexagonal ports and fakes:

| System shape | Recommended structure | System-test boundary (`tests/system/`) |
| :--- | :--- | :--- |
| **Batch / data pipeline** | Vertical job slices (`jobs/<job>/transform.py` pure function `input data -> output data`, optional thin `job.py` shell) + shared pure `core/` + `storage/` for I/O | Call `transform` directly with plain in-memory input data. Do not add ports or fakes for sources and sinks when plain data suffices. |
| **Request-driven service** | Public entrypoint (HTTP/RPC/message handler) + pure domain `core/` + thin ports and adapters for external I/O | Drive the public entrypoint in-process against an in-memory database (SQLite/PGlite/H2) and local fakes for external APIs. |
| **Library / SDK** | Public API module + pure internal domain modules | Call the public API functions and types directly. |
| **CLI** | Thin argument parser + pure command handlers + isolated filesystem/process adapter | Invoke the command handler or CLI runner with in-memory arguments and temporary directories. |

Rules across all shapes:
- **Subtract unused scaffolding**: Do not create `fakes/`, `ports/`, `storage/`, or `jobs/` files that no current `@SPEC-NNN` scenario uses.
- **Keep engine migration cheap**: When the execution engine or framework (for example plain Python vs. Spark/Polars) is still open, keep all I/O in `storage/` and keep transforms pure so the core never changes when the runner changes.
- **Batch fault isolation** (for pipelines): A bad input record must not stop a batch. Skip it deterministically or route it to a rejected-records output, and cover that behavior with a `@SPEC-NNN` scenario when it applies.

## Directory layouts (single-context and monorepo)

### Single-context repository

```text
<repo-root>/
├── CLAUDE.md
├── GLOSSARY.md
├── Makefile
├── .claude/
│   ├── rules/
│   │   ├── architecture.md
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
    ├── conftest.py
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

<1-2 sentences describing what the product, pipeline, service, or library does using GLOSSARY.md terms.>

## Commands (`Makefile`)

```bash
make help                              # List targets and parameters
make check                             # Lint, types, architecture contracts, CVE audit, Gherkin, traceability
make test                              # check + all tests + Dryer + Crapper
make test SPEC=SPEC-001                # Run only the system test for one spec (skips quality gates)
make test MODULE=<name> FILTER=<pat>   # Scope tests to a module or test name pattern
make test SCOPE=unit                   # Run only tests/unit (or SCOPE=system)
make test-all                          # test + Mutator (mutation score >= 80%)
make build                             # Build artifacts
```

## Repository Structure

- `GLOSSARY.md` (or `GLOSSARY-MAP.md` and `<module>/GLOSSARY.md`): Canonical domain terms. Read it before naming a type, function, or scenario.
- `features/` (or `modules/<module>/features/`): Gherkin specifications. Every scenario has a unique `@SPEC-NNN` tag.
- `src/`: Production source code structured for the chosen system shape.
- `tests/system/`: Primary test suite verifying `@SPEC-NNN` scenarios through the public boundary.
- `tests/unit/`: Reserved for isolated logic with high branching complexity.
- `docs/`: Evergreen documentation and reference facts. `docs/adr/` holds Architecture Decision Records (`NNNN-slug.md`).
- `scripts/`: Deterministic guardrails executed by `make`.

## Architecture (enforced by `make check`)

<2-4 bullets stating the module dependency and purity contracts enforced by import-linter / ArchUnit / dependency-cruiser:
- Core domain logic is pure: no I/O, network, process, clock, or randomness.
- Vertical slices / jobs are independent and share code only through `core`.
- Production code never imports `tests`.
If a contract fails, fix the design. Do not weaken the contract without a new ADR.>

## External Systems and Production Safety (include only when applicable)

- Never write to production systems. Ask the user before any change to a shared system.
- <Pointer to evergreen schema/data docs in `docs/` and the corresponding read-only inspection skills in `.claude/skills/`.>

## Engineering Principles

### 1. First Make It Work
- **Attack the premise, subtract before you add.** Delete dead code and unused indirection first.
- **Fix root causes.** Fix the domain model or boundary invariant, not the call sites.
- **Build the lever.** Put repeated checks into `scripts/` and wire them into `make` rather than prose rules.
- **Model the domain.** Use exact terms from `GLOSSARY.md`. Parse and validate at the boundary; keep the core pure.

### 2. Then Make It Right
- **Spec first.** `@SPEC-NNN` scenario -> failing system test -> minimal code -> refactor.
- **Test behavior.** Exercise the public boundary with plain input data or in-memory stores. Never mock internal code.
- **Quality gates:** Crapper `CRAP < 10` and complexity `< 15`. Dryer duplication `< 0.8%`. Mutator `>= 80%`: kill survivors with behavioral assertions, or delete the dead code.

### 3. Practice
- **Guard the context window.** Rules in `.claude/rules/` load by path. Procedures live in `.claude/skills/`. Delegate broad searches to subagents.
- **Protect evergreen assets.** `features/`, `docs/`, and `GLOSSARY.md` must never link to transient plan or scratch files.
- **Small ordered commits.** Keep structural commits separate from behavioral commits.
```

## `GLOSSARY.md` and `GLOSSARY-MAP.md` templates

Define what each domain concept is in 1 to 2 sentences, exclude implementation details, and list rejected synonyms under `_Avoid_`. When a concept is renamed later, move the old name to `_Avoid_`.

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

Group related scenarios into `<capability>.feature` files under `features/` (or `modules/<module>/features/`). Tag every `Scenario` or `Scenario Outline` with a unique `@SPEC-NNN` identifier. Write `@SPEC-001` for the user's first real slice of behavior using real domain IDs and value formats rather than a placeholder example.

```gherkin
Feature: <Capability Name>
  <1-2 sentence outcome description using GLOSSARY.md terms.>

  @SPEC-001
  Scenario: <First real behavior slice using GLOSSARY.md terms and real ID formats>
    Given <initial domain state or input records>
    When <action or transform runs>
    Then <observable outcome>
```

## `docs/README.md` and `docs/adr/` templates

### `docs/README.md`

```markdown
# Documentation Guide

This directory holds evergreen documentation for `<Project Name>`.

## Structure

- `docs/adr/`: Architecture Decision Records (`NNNN-slug.md`) explaining non-obvious technical and domain decisions.
- `docs/<topic>.md`: Evergreen architecture, domain, and external schema documentation. Mark facts from external systems as verified or inferred.

## Spec Traceability Annotations

When documentation traceability is enabled (`REQUIRE_DOC_TRACEABILITY=1`), annotate documented capabilities with covered spec IDs:

```markdown
<!-- specs: SPEC-001 -->
```

## Evergreen Rule

Files in `docs/` are permanent project assets. Do not link to temporary plans, scratch notes, or transient task files.
```

### `docs/adr/0001-agent-first-architecture.md`

```markdown
# 0001: Agent-First Repository Architecture and Verification Loop

## Context

Humans and coding agents need fast, deterministic feedback on domain language, architecture boundaries, behavior, and code quality.

## Decision

- **Architecture**: <System shape and module layout, e.g., vertical job slices with a shared pure core / ports and in-memory adapters>, enforced deterministically in `make check` via `<import-linter / ArchUnit / dependency-cruiser>`.
- **Verification**: Executable Gherkin specifications (`features/` with `@SPEC-NNN` tags) verified by fast system tests (`tests/system/`) using `<plain input data / in-memory store>`.
- **Quality gates**: `make test` enforces Dryer (`duplication < 0.8%`) and Crapper (`CRAP < 10`, complexity `< 15`). `make test-all` enforces Mutator (`>= 80%`).
```

## Parameterized `Makefile` template

Keep top-level targets to five commands (`help`, `check`, `test`, `test-all`, `build`) and expose knobs through variables (`MODULE`, `SPEC`, `FILTER`, `SCOPE`).

Note two ordering rules:
1. `check` runs static guardrails (formatter, linter, type checker, import/architecture contracts, CVE audit, Gherkin syntax, and traceability).
2. `test` runs the test suite with coverage first, and then runs `scripts/check-quality --fast` (Dryer + Crapper) only on unfiltered runs—because CRAP requires full coverage data from the entire test suite.

```makefile
.PHONY: help check test test-all build

MODULE ?=
SPEC   ?=
FILTER ?=
SCOPE  ?=

TEST_PATH := tests$(if $(SCOPE),/$(SCOPE),)
SPEC_K    := $(subst -,_,$(shell echo '$(SPEC)' | tr '[:upper:]' '[:lower:]'))
K_EXPR    := $(if $(SPEC),$(SPEC_K),$(FILTER))
FILTERED  := $(MODULE)$(SPEC)$(FILTER)$(SCOPE)

help: ## Show available commands and parameters
	@printf "Targets:\n"
	@printf "  make check                                    Lint, types, architecture, CVE audit, Gherkin, traceability\n"
	@printf "  make test [MODULE=] [SPEC=] [FILTER=] [SCOPE=] check + tests; Dryer and Crapper on full runs only\n"
	@printf "  make test-all                                 test + Mutator (mutation score >= 80%%)\n"
	@printf "  make build                                    Build project artifacts\n"

check: ## Deterministic static guardrails
	# 1. Stack formatter, linter, strict type checker, architecture contracts, and dependency CVE check
	<lint-typecheck-arch-audit-commands>
	# 2. Gherkin and @SPEC-NNN traceability checks
	./scripts/check-features $(if $(MODULE),--module $(MODULE),)
	./scripts/check-traceability $(if $(MODULE),--module $(MODULE),)

test: check ## Guardrails + tests + fast quality gates
	# Run tests (filtered by TEST_PATH and K_EXPR when set) and emit coverage.json
	<test-runner-command-with-coverage>
	$(if $(FILTERED),@echo "quality: skipped for filtered runs",./scripts/check-quality --fast)

test-all: test ## Full loop including mutation testing
	./scripts/check-quality --all

build: ## Build project artifacts
	<build-command>
```
