# Deterministic Guardrail Scripts and Quality Signals

Disclosed reference for Step 5 of [`agent-first-repo-setup`](../SKILL.md). Use these patterns and scripts to enforce Gherkin validity, spec-to-test/doc traceability, and software quality thresholds deterministically.

## Contents

- Stack matrix for fast system tests and quality signals
- `scripts/check-features` reference script
- `scripts/check-traceability` reference script
- `scripts/check-quality` reference script

## Stack matrix for fast system tests and quality signals

Select the tools that match the project stack confirmed in Step 1:

| Stack | In-Memory / Fast DB for System Tests | Fast Quality Signals (`make test`: Dryer < 0.8%, Crapper < 10) | Mutation Testing (`make test-all`: Mutator >= 80%) |
| :--- | :--- | :--- | :--- |
| **TypeScript / JS** | SQLite (`:memory:`), PGlite (in-memory Postgres), in-memory fakes | `npx jscpd` (Dryer `< 0.8%`), ESLint `sonarjs/cognitive-complexity` (`< 15`), CRAP check (`< 10`) via Vitest/c8 coverage | Stryker (`npx stryker run`, `>= 80%`) |
| **Python** | SQLite (`:memory:`), `fakeredis`, ASGI/WSGI in-process test client (`httpx.ASGITransport`) | `npx jscpd` (`< 0.8%`), `radon cc` + `coverage.py` CRAP check (`CRAP < 10`, complexity `< 15`) | `mutmut` or `cosmic-ray` (`>= 80%`) |
| **Java / Kotlin** | H2 (Postgres/MySQL compatibility mode) or shared singleton Testcontainer with transaction rollback, WireMock / in-memory fakes | `jscpd` or PMD CPD (`< 0.8%`), PMD `CognitiveComplexity` (`< 15`), JaCoCo + `crap4java` (`CRAP < 10`) | PIT (`pitest-maven` / `gradle-pitest-plugin`, `>= 80%`) |
| **Go** | SQLite (`:memory:`), `miniredis`, `httptest.NewServer` with in-memory adapters | `jscpd` / `dupl` (`< 0.8%`), `gocognit` (`< 15`), `gocyclo` + `go test -coverprofile` CRAP check (`< 10`) | `gremlins` or `go-mutesting` (`>= 80%`) |
| **Rust** | SQLite (`:memory:`), in-process `tower::ServiceExt::oneshot`, trait-based in-memory fakes | `jscpd` (`< 0.8%`), `cargo clippy -- -D clippy::cognitive_complexity` | `cargo-mutants` (`>= 80%`) |

## `scripts/check-features` reference script

Validates that `features/` (or every module's `features/` directory in a monorepo) contains valid Gherkin `.feature` files and that every `Scenario` or `Scenario Outline` has a unique `@SPEC-...` tag. Uses Python 3 (pre-installed on macOS and Linux CI runners) or the repo's native runtime.

```python
#!/usr/bin/env python3
"""Validate Gherkin feature files and unique @SPEC-NNN scenario tags."""

import argparse
import pathlib
import re
import sys

SPEC_TAG_RE = re.compile(r"@([A-Z0-9_-]*SPEC-[0-9]{3,})\b")
SCENARIO_RE = re.compile(r"^\s*(Scenario|Scenario Outline|Scenario Template):\s*(.+)$")
FEATURE_RE = re.compile(r"^\s*Feature:\s*(.+)$")
STEP_RE = re.compile(r"^\s*(Given|When|Then|And|But|\*)\s+.+$")
STRUCTURAL_RE = re.compile(
    r"^\s*(Background:|Examples:|Scenarios:|Rule:|@|\||\"\"\"|#)"
)


def find_feature_dirs(root: pathlib.Path, module: str | None) -> list[pathlib.Path]:
    modules_dir = root / "modules"
    if modules_dir.is_dir():
        if module:
            target = modules_dir / module / "features"
            return [target]
        return [
            m / "features"
            for m in sorted(modules_dir.iterdir())
            if m.is_dir() and not m.name.startswith(".")
        ]
    return [root / "features"]


def validate_file(path: pathlib.Path, seen_specs: dict[str, str]) -> list[str]:
    errors: list[str] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    has_feature = False
    pending_tags: list[tuple[str, int]] = []
    in_docstring = False
    scenario_count = 0

    for idx, raw in enumerate(lines, start=1):
        stripped = raw.strip()
        if stripped.startswith('"""') or stripped.startswith("'''"):
            in_docstring = not in_docstring
            continue
        if in_docstring or not stripped or stripped.startswith("#"):
            continue

        if FEATURE_RE.match(raw):
            has_feature = True
            pending_tags.clear()
            continue

        tags = SPEC_TAG_RE.findall(raw)
        if stripped.startswith("@"):
            for tag in tags:
                pending_tags.append((tag, idx))
            continue

        scenario_match = SCENARIO_RE.match(raw)
        if scenario_match:
            scenario_count += 1
            if not has_feature:
                errors.append(f"{path}:{idx}: Scenario appears before 'Feature:' header.")
            if not pending_tags:
                errors.append(
                    f"{path}:{idx}: Scenario '{scenario_match.group(2)}' is missing a preceding @SPEC-NNN tag."
                )
            for tag, tag_line in pending_tags:
                loc = f"{path}:{tag_line}"
                if tag in seen_specs:
                    errors.append(
                        f"{loc}: Duplicate @{tag} tag (already defined at {seen_specs[tag]})."
                    )
                else:
                    seen_specs[tag] = loc
            pending_tags.clear()
            continue

        if not has_feature:
            continue

        if not STEP_RE.match(raw) and not STRUCTURAL_RE.match(raw):
            # Allow freeform feature description lines immediately after Feature: before first Scenario
            if scenario_count > 0:
                errors.append(
                    f"{path}:{idx}: Unrecognized Gherkin line inside scenario: '{stripped}'. "
                    "Start steps with Given, When, Then, And, or But."
                )

    if not has_feature:
        errors.append(f"{path}:1: Missing 'Feature: <title>' declaration.")
    if scenario_count == 0:
        errors.append(f"{path}:1: Feature file contains no Scenario definitions.")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--module", help="Validate only the named monorepo module")
    args = parser.parse_args()

    root = pathlib.Path(__file__).resolve().parent.parent
    feature_dirs = find_feature_dirs(root, args.module)
    errors: list[str] = []
    seen_specs: dict[str, str] = {}
    total_files = 0

    for fdir in feature_dirs:
        if not fdir.is_dir():
            errors.append(
                f"Missing features directory: {fdir.relative_to(root)}. "
                "Create it and add at least one <capability>.feature file."
            )
            continue
        files = sorted(fdir.rglob("*.feature"))
        if not files:
            errors.append(f"No .feature files found in {fdir.relative_to(root)}.")
            continue
        for fpath in files:
            total_files += 1
            errors.extend(validate_file(fpath.relative_to(root), seen_specs))

    if errors:
        print("Gherkin feature validation failed:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(
        f"features ok: {total_files} feature file(s), {len(seen_specs)} unique @SPEC tag(s)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## `scripts/check-traceability` reference script

Verifies two deterministic invariants:
1. Every `@SPEC-NNN` tag defined in `features/` is referenced in at least one system test under `tests/system/` (and in `docs/` when `REQUIRE_DOC_TRACEABILITY=1`).
2. Evergreen files (`features/`, `docs/`, `GLOSSARY*.md`) do not reference transient scratch or plan files (`.scratch/`, `plan.md`, `intent.md`, `tasks.md`).

```python
#!/usr/bin/env python3
"""Verify @SPEC-NNN traceability across features, system tests, and docs."""

import argparse
import os
import pathlib
import re
import sys

SPEC_DEF_RE = re.compile(r"@([A-Z0-9_-]*SPEC-[0-9]{3,})\b")
TRANSIENT_REF_RE = re.compile(
    r"(\.scratch/|(?<![a-zA-Z0-9_-])(plan|intent|scratch|todo)\.md\b)",
    re.IGNORECASE,
)


def collect_text(paths: list[pathlib.Path]) -> str:
    chunks: list[str] = []
    for base in paths:
        if not base.exists():
            continue
        files = [base] if base.is_file() else [p for p in base.rglob("*") if p.is_file()]
        for fpath in files:
            try:
                chunks.append(fpath.read_text(encoding="utf-8"))
            except UnicodeDecodeError:
                continue
    return "\n".join(chunks)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--module", help="Check only the named monorepo module")
    args = parser.parse_args()

    root = pathlib.Path(__file__).resolve().parent.parent
    require_docs = os.environ.get("REQUIRE_DOC_TRACEABILITY", "1") == "1"

    modules_dir = root / "modules"
    if modules_dir.is_dir():
        targets = (
            [modules_dir / args.module]
            if args.module
            else [m for m in sorted(modules_dir.iterdir()) if m.is_dir() and not m.name.startswith(".")]
        )
    else:
        targets = [root]

    errors: list[str] = []
    total_specs = 0
    docs_text = collect_text([root / "docs"])

    for target in targets:
        fdir = target / "features"
        sys_test_dir = target / "tests" / "system"
        fallback_test_dir = target / "tests"
        test_search_dir = sys_test_dir if sys_test_dir.is_dir() else fallback_test_dir
        tests_text = collect_text([test_search_dir])
        local_docs_text = docs_text + "\n" + collect_text([target / "docs"])

        for fpath in sorted(fdir.rglob("*.feature")) if fdir.is_dir() else []:
            content = fpath.read_text(encoding="utf-8")
            for spec_id in SPEC_DEF_RE.findall(content):
                total_specs += 1
                if spec_id not in tests_text:
                    rel_test = test_search_dir.relative_to(root) if test_search_dir.exists() else "tests/system"
                    errors.append(
                        f"@{spec_id} (in {fpath.relative_to(root)}) has no system test reference in {rel_test}. "
                        f"Add a system test annotated with '{spec_id}'."
                    )
                if require_docs and spec_id not in local_docs_text:
                    errors.append(
                        f"@{spec_id} (in {fpath.relative_to(root)}) is not documented in docs/. "
                        f"Document the behavior in docs/ and add '<!-- specs: {spec_id} -->'."
                    )

    evergreen_roots = [root / "docs", root / "features"] + list(root.glob("GLOSSARY*.md"))
    if modules_dir.is_dir():
        evergreen_roots.extend(modules_dir.glob("*/features"))
        evergreen_roots.extend(modules_dir.glob("*/docs"))
        evergreen_roots.extend(modules_dir.glob("*/GLOSSARY*.md"))

    for eb in evergreen_roots:
        files = [eb] if eb.is_file() else (list(eb.rglob("*")) if eb.is_dir() else [])
        for fpath in files:
            if not fpath.is_file():
                continue
            try:
                lines = fpath.read_text(encoding="utf-8").splitlines()
            except UnicodeDecodeError:
                continue
            for idx, line in enumerate(lines, start=1):
                match = TRANSIENT_REF_RE.search(line)
                if match:
                    errors.append(
                        f"{fpath.relative_to(root)}:{idx}: Evergreen file references transient asset '{match.group(0)}'. "
                        "Remove links to temporary plans or scratch files."
                    )

    if errors:
        print("Traceability check failed:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(f"traceability ok: {total_specs} @SPEC tag(s) verified in system tests and docs.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## `scripts/check-quality` reference script

Enforces fast software quality signals during `make test` (`--fast`: **Dryer** duplication `< 0.8%` and **Crapper** `CRAP < 10` / complexity `< 15`) and exhaustive signals during `make test-all` (`--all`: **Mutator** mutation testing threshold). Adapt the tool invocations to the stack selected in Step 1.

```bash
#!/usr/bin/env bash
# Enforce deterministic software quality gates:
#   --fast : Dryer (duplication < 0.8%) and Crapper (CRAP < 10, complexity < 15) (runs on make test)
#   --all  : --fast plus Mutator (mutation score >= 80%, kill survivors or delete dead code) (runs on make test-all)

set -euo pipefail

MODE="--fast"
MODULE=""
SCOPE="changed"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast|--all) MODE="$1"; shift ;;
    --module) MODULE="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    *) echo "Unknown option: $1 (valid: --fast, --all, --module <name>, --scope changed|all)" >&2; exit 2 ;;
  esac
done

MAX_DUPLICATION_PCT="${MAX_DUPLICATION_PCT:-0.8}" # Dryer: keep clone density below 0.8%
MAX_COMPLEXITY="${MAX_COMPLEXITY:-15}"            # Keep cognitive/cyclomatic complexity below 15
MAX_CRAP="${MAX_CRAP:-10}"                        # Crapper: keep CRAP change-risk score below 10
MIN_MUTATION_PCT="${MIN_MUTATION_PCT:-80}"        # Mutator: require at least 80% killed mutants

echo "quality: running fast checks (Dryer < ${MAX_DUPLICATION_PCT}%, Crapper CRAP < ${MAX_CRAP}, complexity < ${MAX_COMPLEXITY})..."

# 1. Dryer / Duplication check (replace or invoke stack-configured clone detector, e.g. jscpd)
# npx --yes jscpd src/ --threshold "${MAX_DUPLICATION_PCT}" --silent

# 2. Crapper / Complexity check (invoke stack-configured CRAP and complexity analyzer)
# <crap-and-complexity-command>

if [[ "$MODE" == "--all" ]]; then
  echo "quality: running Mutator checks (threshold >= ${MIN_MUTATION_PCT}%: cover uncovered, kill survivors, or delete dead code)..."
  # 3. Mutation testing (invoke PIT / Stryker / mutmut / cargo-mutants / gremlins)
  # <mutation-test-command>
fi

echo "quality ok (${MODE})."
```

When generating `scripts/check-quality` for a specific repository, wire the real stack check commands (or a lightweight built-in AST/line analyzer when external CLI tools are not yet installed) so that `make test` and `make test-all` execute real assertions immediately.
