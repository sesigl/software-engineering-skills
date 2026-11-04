# Deterministic Guardrail Scripts and Quality Signals

Disclosed reference for Step 5 of [`agent-first-repo-setup`](../SKILL.md). Use these patterns and scripts to enforce architecture contracts, Gherkin validity, spec traceability, and software quality thresholds deterministically.

## Contents

- Stack matrix for architecture contracts, system tests, and quality signals
- `scripts/check-features` reference script
- `scripts/check-traceability` reference script
- `scripts/check-quality` reference script
- Python reference scripts and configuration
- Stack and CI gotchas

## Stack matrix for architecture contracts, system tests, and quality signals

Select the tools that match the system shape and project stack confirmed in Step 1:

| Stack | Architecture Contracts (`make check`) | Fast System-Test Boundary (`tests/system/`) | Fast Quality Signals (`make test`: Dryer < 0.8%, Crapper < 10) | Mutation Testing (`make test-all`: Mutator >= 80%) |
| :--- | :--- | :--- | :--- | :--- |
| **TypeScript / JS** | `dependency-cruiser` (`npx depcruise src`) | Plain input data (pipelines/libs), or SQLite (`:memory:`), PGlite, and local fakes | `npx jscpd` (Dryer `< 0.8%`), ESLint `sonarjs/cognitive-complexity` (`< 15`), CRAP check (`< 10`) via Vitest/c8 coverage | Stryker (`npx stryker run`, `>= 80%`) |
| **Python** | `import-linter` (`uv run lint-imports`) | Plain input data calling pure transforms, or SQLite (`:memory:`), `fakeredis`, and `httpx.ASGITransport` | `jscpd` (`< 0.8%`), `radon` cyclomatic complexity + `coverage.json` per-function CRAP (`CRAP < 10`, complexity `< 15`) | `mutmut >= 3.2` (`>= 80%` via `mutants/**/*.meta`) |
| **Java / Kotlin** | `ArchUnit` | Plain input data, or H2 / shared singleton Testcontainer with rollback and WireMock / local fakes | `jscpd` or PMD CPD (`< 0.8%`), PMD `CognitiveComplexity` (`< 15`), JaCoCo + CRAP check (`CRAP < 10`) | PIT (`pitest-maven` / `gradle-pitest-plugin`, `>= 80%`) |
| **Go** | `depguard` (`golangci-lint`) | Plain input data, or SQLite (`:memory:`), `miniredis`, and `httptest.NewServer` | `jscpd` / `dupl` (`< 0.8%`), `gocognit` (`< 15`), `gocyclo` + `go test -coverprofile` CRAP check (`< 10`) | `gremlins` or `go-mutesting` (`>= 80%`) |
| **Rust** | Workspace crate boundaries + `cargo-deny` | Plain input data, or SQLite (`:memory:`), `tower::ServiceExt::oneshot`, and trait fakes | `jscpd` (`< 0.8%`), `cargo clippy -- -D clippy::cognitive_complexity` | `cargo-mutants` (`>= 80%`) |

## `scripts/check-features` reference script

Validates that `features/` (or every module's `features/` directory in a monorepo) contains valid Gherkin `.feature` files and that every `Scenario` or `Scenario Outline` has a unique `@SPEC-...` tag. When `gherkin-official` is installed, it also runs the official Cucumber parser so invalid Gherkin syntax that passes line regexes fails deterministically.

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


def parse_errors(path: pathlib.Path) -> list[str]:
    """Strict syntax check with the official Cucumber Gherkin parser when installed."""
    try:
        from gherkin.parser import Parser  # noqa: PLC0415
    except ImportError:
        return []
    try:
        Parser().parse(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        return [f"{path}: Gherkin parse error: {exc}"]
    return []


def validate_file(path: pathlib.Path, seen_specs: dict[str, str]) -> list[str]:
    errors: list[str] = parse_errors(path)
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

Verifies three deterministic invariants:
1. Every `@SPEC-NNN` tag defined in `features/` is referenced in at least one system test under `tests/system/` (and in `docs/` when `REQUIRE_DOC_TRACEABILITY=1`; set the default from the user's Step 1 answer, `"0"` when doc annotations are optional).
2. Evergreen files (`features/`, `docs/`, `GLOSSARY*.md`) do not reference transient scratch or plan files (`.scratch/`, `plan.md`, `intent.md`, `scratch.md`, `todo.md`).
3. Every `.claude/rules/*.md` file starts at line 1 with `---` (catching accidental ```` ```markdown ```` fences that break `paths:` scoping).

```python
#!/usr/bin/env python3
"""Verify @SPEC-NNN traceability, evergreen hygiene, and rule frontmatter."""

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
    # Set default to "1" when the user opted into required doc traceability in Step 1, else "0".
    require_docs = os.environ.get("REQUIRE_DOC_TRACEABILITY", "0") == "1"

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
                snake_id = spec_id.lower().replace("-", "_")
                if spec_id not in tests_text and snake_id not in tests_text.lower():
                    rel_test = test_search_dir.relative_to(root) if test_search_dir.exists() else "tests/system"
                    errors.append(
                        f"@{spec_id} (in {fpath.relative_to(root)}) has no system test reference in {rel_test}. "
                        f"Add a system test named 'test_{snake_id}_...' or annotated with '@{spec_id}'."
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

    rules_dir = root / ".claude" / "rules"
    if rules_dir.is_dir():
        for rule_file in sorted(rules_dir.rglob("*.md")):
            lines = rule_file.read_text(encoding="utf-8").splitlines()
            if not lines or lines[0].strip() != "---":
                errors.append(
                    f"{rule_file.relative_to(root)}:1: Rule file must start with '---' YAML frontmatter "
                    "(remove any leading markdown code fence)."
                )

    if errors:
        print("Traceability check failed:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(f"traceability ok: {total_specs} @SPEC tag(s) verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## `scripts/check-quality` reference script

Enforces fast software quality signals during `make test` (`--fast`: **Dryer** duplication `< 0.8%` and **Crapper** `CRAP < 10` / complexity `< 15`) and full signals during `make test-all` (`--all`: **Mutator** mutation testing threshold `>= 80%`).

```bash
#!/usr/bin/env bash
# Deterministic quality gates:
#   --fast : Dryer (duplication < 0.8%) and Crapper (CRAP < 10, complexity < 15). Needs coverage.json.
#   --all  : --fast plus Mutator (mutation score >= 80%).
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="--fast"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast|--all) MODE="$1"; shift ;;
    *) echo "Unknown option: $1 (valid: --fast, --all)" >&2; exit 2 ;;
  esac
done

export MAX_DUPLICATION_PCT="${MAX_DUPLICATION_PCT:-0.8}" # Dryer: clone density below 0.8%
export MAX_COMPLEXITY="${MAX_COMPLEXITY:-15}"            # Complexity below 15
export MAX_CRAP="${MAX_CRAP:-10}"                        # Crapper: CRAP score below 10
export MIN_MUTATION_PCT="${MIN_MUTATION_PCT:-80}"        # Mutator: at least 80% killed mutants

JSCPD="jscpd"
command -v jscpd >/dev/null 2>&1 || JSCPD="npx --yes jscpd"
echo "dryer: duplication must be < ${MAX_DUPLICATION_PCT}%"
$JSCPD src tests --threshold "${MAX_DUPLICATION_PCT}" --reporters console --silent --ignore "**/__pycache__/**"

# Replace with the stack CRAP checker (Python reference: scripts/crap_report.py)
uv run python scripts/crap_report.py

if [[ "$MODE" == "--all" ]]; then
  # Replace with the stack mutation runner (Python reference: mutmut + scripts/mutation_score.py)
  rm -rf mutants
  uv run mutmut run
  uv run python scripts/mutation_score.py
fi
echo "quality ok (${MODE})."
```

## Python reference scripts and configuration

When the repository uses Python (`uv`, `pytest-bdd`, `ruff`, `mypy`, `import-linter`, `radon`, `mutmut`), use these reference implementations:

### `scripts/crap_report.py` (Radon cyclomatic complexity + `coverage.json`)

Note: `radon` measures **cyclomatic complexity**, not cognitive complexity. State this clearly in the script docstring and `CLAUDE.md`.

```python
"""Crapper: fail when a function has CRAP >= MAX_CRAP or cyclomatic complexity >= MAX_COMPLEXITY.

CRAP = complexity^2 * (1 - coverage)^3 + complexity. Complexity is radon cyclomatic
complexity (not cognitive complexity). Coverage is the line coverage of the function
body from coverage.json.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import TYPE_CHECKING, Any

from radon.complexity import cc_visit

if TYPE_CHECKING:
    from collections.abc import Iterator

ROOT = Path(__file__).resolve().parent.parent
COVERAGE_FILE = ROOT / "coverage.json"


def _source_files() -> list[Path]:
    modules_dir = ROOT / "modules"
    if modules_dir.is_dir():
        return sorted(modules_dir.glob("*/src/**/*.py"))
    return sorted((ROOT / "src").rglob("*.py"))


def _functions(blocks: list[Any]) -> Iterator[Any]:
    for block in blocks:
        if hasattr(block, "methods"):
            yield from block.methods
        else:
            yield block


def _coverage(file_data: dict[str, Any] | None, start: int, end: int) -> float:
    if file_data is None:
        return 0.0
    executed = {line for line in file_data["executed_lines"] if start <= line <= end}
    missing = {line for line in file_data["missing_lines"] if start <= line <= end}
    statements = len(executed) + len(missing)
    return 1.0 if statements == 0 else len(executed) / statements


def main() -> int:
    max_crap = float(os.environ.get("MAX_CRAP", "10"))
    max_complexity = int(os.environ.get("MAX_COMPLEXITY", "15"))
    if not COVERAGE_FILE.is_file():
        print("crapper: coverage.json is missing. Run tests with coverage first (make test).")
        return 1
    files = json.loads(COVERAGE_FILE.read_text(encoding="utf-8"))["files"]
    violations: list[str] = []
    checked = 0
    for path in _source_files():
        relative = str(path.relative_to(ROOT))
        for func in _functions(cc_visit(path.read_text(encoding="utf-8"))):
            checked += 1
            coverage = _coverage(files.get(relative), func.lineno, func.endline)
            crap = func.complexity**2 * (1 - coverage) ** 3 + func.complexity
            if crap >= max_crap or func.complexity >= max_complexity:
                violations.append(
                    f"{relative}:{func.lineno} {func.name}: CRAP={crap:.1f} "
                    f"complexity={func.complexity} coverage={coverage:.0%}. "
                    "Cover the branches with a system test or flatten the control flow."
                )
    if violations:
        print("crapper failed:", *violations, sep="\n  - ")
        return 1
    print(f"crapper ok: {checked} function(s), CRAP < {max_crap:g}, complexity < {max_complexity}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

### `scripts/mutation_score.py` (`mutmut 3` metadata reader)

`mutmut 3` writes per-file `.meta` JSON files under `mutants/` with `exit_code_by_key` (`0` = survived, `33` = no tests, `34` = skipped; any other integer exit code = killed).

```python
"""Mutator: fail when the mutmut 3 score is below MIN_MUTATION_PCT."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NOT_KILLED = {0, 33, 34, None}


def main() -> int:
    minimum = float(os.environ.get("MIN_MUTATION_PCT", "80"))
    codes: list[int | None] = []
    for meta in (ROOT / "mutants").rglob("*.meta"):
        codes.extend(json.loads(meta.read_text(encoding="utf-8"))["exit_code_by_key"].values())
    if not codes:
        print("mutator: no mutants found. Run `uv run mutmut run` first.")
        return 1
    killed = sum(code not in NOT_KILLED for code in codes)
    score = 100 * killed / len(codes)
    if score < minimum:
        print(
            f"mutator failed: {score:.1f}% killed ({killed}/{len(codes)}) < {minimum:g}%. "
            "Run `uv run mutmut results`, then kill survivors with behavioral assertions "
            "or delete the dead code."
        )
        return 1
    print(f"mutator ok: {score:.1f}% killed ({killed}/{len(codes)}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

### `tests/conftest.py` (Register `@SPEC-NNN` marks for `pytest-bdd`)

`pytest-bdd` converts `@SPEC-NNN` Gherkin tags into pytest marks. When `filterwarnings = ["error"]` is active, unregistered `@SPEC-NNN` marks fail with `PytestUnknownMarkWarning`. Register them dynamically from `features/`:

```python
from __future__ import annotations

import re
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import pytest

_ROOT = Path(__file__).resolve().parent.parent
_SEARCH_ROOT = _ROOT / "modules" if (_ROOT / "modules").is_dir() else _ROOT / "features"
_SPEC_TAG = re.compile(r"@([A-Z0-9_-]*SPEC-\d{3,})\b")


def pytest_configure(config: pytest.Config) -> None:
    """Register every @SPEC-NNN tag in features/ as a pytest marker."""
    for feature in _SEARCH_ROOT.rglob("*.feature"):
        for spec in _SPEC_TAG.findall(feature.read_text(encoding="utf-8")):
            config.addinivalue_line("markers", f"{spec}: Gherkin scenario {spec}")
```

### Python `pyproject.toml` architecture and tool baseline

Install the required packages in the `dev` dependency group (`uv sync --locked`) before running the guardrail scripts:

```toml
[dependency-groups]
dev = [
    "coverage[toml]>=7.6",
    "gherkin-official>=29.0",
    "import-linter>=2.1",
    "mutmut>=3.2",
    "mypy>=1.13",
    "pip-audit>=2.7",
    "pytest>=8.3",
    "pytest-bdd>=8.0",
    "pytest-cov>=6.0",
    "radon>=6.0",
    "ruff>=0.8",
]

[tool.ruff.lint]
select = ["ALL"]
ignore = [
    "CPY001",  # no per-file copyright header
    "D",       # docstrings: names and types carry meaning; add docstrings where intent is non-obvious
    "COM812",  # conflicts with ruff formatter
    "ISC001",  # conflicts with ruff formatter
]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101", "PLR2004", "INP001", "ANN201"]
"scripts/**" = ["INP001", "T201", "S603", "S607"]

[tool.mypy]
strict = true
warn_unreachable = true
enable_error_code = ["ignore-without-code", "redundant-expr", "truthy-bool", "explicit-override"]
files = ["src", "tests", "scripts"]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["-q", "--import-mode=importlib", "-p", "no:cacheprovider"]
xfail_strict = true
filterwarnings = ["error"]

[tool.mutmut]
source_paths = ["src/<package>/"]
also_copy = ["features/", "scripts/"]

[tool.importlinter]
root_package = "<package>"
include_external_packages = true

[[tool.importlinter.contracts]]
name = "Core and transforms are pure: no I/O, network, process, clock, or randomness"
type = "forbidden"
source_modules = ["<package>.core", "<package>.jobs.*.transform"]
forbidden_modules = [
    "<package>.storage",
    "os", "io", "pathlib", "shutil", "tempfile", "glob", "socket", "ssl", "http", "urllib",
    "subprocess", "multiprocessing", "threading", "asyncio", "sqlite3", "pickle", "logging",
    "time", "datetime", "random",
]

[[tool.importlinter.contracts]]
name = "Slices/jobs are independent"
type = "independence"
modules = ["<package>.jobs.*"]

[[tool.importlinter.contracts]]
name = "Production code never imports tests"
type = "forbidden"
source_modules = ["<package>"]
forbidden_modules = ["tests"]
allow_indirect_imports = true
```

## Stack and CI gotchas

- **`mutmut 3` configuration**: `paths_to_mutate` is deprecated; use `source_paths = ["src/<package>/"]`. Because `mutmut 3` runs tests inside a copied `mutants/` directory, set `also_copy = ["features/", "scripts/"]` whenever tests read `.feature` files or helper scripts.
- **`pip-audit` on an editable `uv` project**: `pip-audit` fails when it tries to audit the local editable project from PyPI. Audit the locked third-party dependencies instead:
  `uv export --frozen --no-emit-project --no-hashes --quiet | uv run pip-audit --strict --disable-pip --no-deps --progress-spinner off -r /dev/stdin`
- **`jscpd 5` flags and version pinning**: `jscpd 5` removed the `--gitignore` flag; pass explicit `--ignore` globs (such as `--ignore "**/__pycache__/**"`). Pin the same `jscpd` version in CI (for example `npm install --global jscpd@5.4.2`) as locally so clone counts do not drift.
- **CI verification in a clean checkout**: When you generate a CI workflow (`.github/workflows/ci.yml` or `Jenkinsfile`), verify that `make test-all` passes in a fresh `git clone` of the committed state so untracked local files do not hide missing `also_copy` or lockfile entries.
