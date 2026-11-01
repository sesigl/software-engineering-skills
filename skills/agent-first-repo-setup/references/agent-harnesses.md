# Agent Harness Research and Context Mapping

Disclosed reference for Steps 2 to 5 of [`agent-first-repo-setup`](../SKILL.md). Use it when the user selects one or more agent harnesses other than Claude Code.

The concepts are the same for every harness: one lean always-on instruction file, rules that load only for matching files, and skills that load on demand. The file locations, frontmatter keys, and scoping mechanisms are different for each harness, and they change between releases. Do not use remembered conventions. Research the current documentation for each selected harness before you present the blueprint.

## Contents

- Concepts to map
- Research procedure
- Decision rules
- `scripts/check-agent-context` reference script
- Pitfalls

## Concepts to map

Find the current mechanism for each of these concepts in each selected harness:

| Concept | Question to answer from the documentation |
| --- | --- |
| Always-on instructions | Which file does the harness load at session start (for example `AGENTS.md`, `CLAUDE.md`, a harness-specific file)? Can that file import another file? Is there a size limit? |
| Glob-scoped rules | Can a rule load only when the agent touches files that match a glob? Which directory, file extension, and frontmatter key does it use? |
| Directory-scoped rules | Does the harness read nested instruction files in subdirectories? Which file wins on conflict? |
| On-demand skills | Which project directories does the harness scan for `SKILL.md`? Does it read the shared `.agents/skills/` directory or another harness's directory? |
| Harness-only features | Hooks, subagents, command permissions, or settings files that have no equivalent in the other selected harnesses. |

## Research procedure

1. For each selected harness, read its current official documentation. Use the documentation tools that are available, in this sequence: a documentation MCP server (for example Context7), then a web fetch of the vendor documentation, then a web search.
2. Record each answer from the concept table with the source URL.
3. If you cannot get the documentation (for example, there is no network access), say which facts are not verified and ask the user to confirm them in the blueprint. Do not present unverified facts as verified.
4. Show the findings as a short table in the Step 2 blueprint, so that the user can correct them before you write files.
5. After the user approves, record the selected harnesses, the chosen file layout, and the source URLs in `docs/adr/0001-agent-first-architecture.md`. Future maintainers can then check the layout when a harness changes.

## Decision rules

Apply these rules to the verified findings. Generate files only for the harnesses that the user selected.

1. **Only Claude Code (default)**: Use `CLAUDE.md`, `.claude/rules/`, and `.claude/skills/` as the SKILL.md steps describe. Do not create files for other harnesses.
2. **One source of truth for instructions**: Write the project instructions (the `CLAUDE.md` template from `repo-templates.md`) to one canonical file. Prefer the file that most selected harnesses read natively (usually `AGENTS.md`). For a harness that does not read it, write the smallest adapter that the documentation allows: an import line (for example `@AGENTS.md` in `CLAUDE.md`) or a setting that adds the canonical file to the context. Copy the body only when no import or setting exists, and let `scripts/check-agent-context` compare the copies.
3. **One body per rule topic**: Keep one body for each rule topic (`features`, `testing`, `docs-and-adrs`, `scripts-and-build`) and render it in the format of each selected harness:
   - Use glob-scoped rules where the harness supports them, because they load the least context.
   - Use a nested instruction file in the covered directory (for example `features/AGENTS.md`) for a harness that supports only directory scope. If part of the scope is a root file (for example `Makefile`), add one pointer line to the root instruction file.
   - Do not render a rule twice for the same harness. If a harness reads both a nested file and its own glob-scoped rule for the same scope, keep only one of them.
4. **Shared skills directory**: Write each skill once, in the directory that most selected harnesses read (usually `.agents/skills/`). For a harness that does not read that directory, add a relative symlink from its skills directory to the shared one. If symlinks are not available (for example on Windows without developer mode), copy the files and let `scripts/check-agent-context` compare them.
5. **Harness-only features stay local**: Put hooks, subagents, and permissions only in the directory of the harness that supports them. Do not try to simulate them in other harnesses.
6. **Drift guardrail**: When two or more harnesses are selected, generate `scripts/check-agent-context` and run it from `make check`.

## `scripts/check-agent-context` reference script

The script does not contain harness knowledge. Fill the three maps from the approved blueprint. Port the script to the project language if the stack has no Python.

```python
#!/usr/bin/env python3
"""Fail when the agent context files of the selected harnesses drift apart."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Rule topic -> {rendered file: required frontmatter key, or None for no frontmatter}.
RULES = {
    "features": {".claude/rules/features.md": "paths", "features/AGENTS.md": None},
}
# Adapter file -> text it must contain to import the canonical instruction file.
ADAPTERS = {"CLAUDE.md": "@AGENTS.md"}
# Canonical skills directory -> directories that must contain the same skills.
SKILL_MIRRORS = {".agents/skills": [".claude/skills"]}

FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.S)
errors = []


def read(relative):
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"missing {relative}")
        return None
    return path.read_text()


for topic, files in RULES.items():
    bodies = set()
    for relative, key in files.items():
        text = read(relative)
        if text is None:
            continue
        match = FRONTMATTER.match(text)
        if key and not (match and re.search(rf"^{key}:", match.group(1), re.M)):
            errors.append(f"{relative} needs '{key}:' frontmatter")
        bodies.add(FRONTMATTER.sub("", text).strip())
    if len(bodies) > 1:
        errors.append(f"rule '{topic}' differs between: {', '.join(files)}")

for relative, needle in ADAPTERS.items():
    text = read(relative)
    if text is not None and needle not in text:
        errors.append(f"{relative} must contain '{needle}'")

for source, mirrors in SKILL_MIRRORS.items():
    for skill in sorted((ROOT / source).glob("*/SKILL.md")):
        for mirror in mirrors:
            copy = ROOT / mirror / skill.relative_to(ROOT / source)
            if not copy.is_file() or copy.read_text() != skill.read_text():
                errors.append(f"{copy.relative_to(ROOT)} must match "
                              f"{skill.relative_to(ROOT)} (use a symlink)")

for error in errors:
    print(f"check-agent-context: {error}", file=sys.stderr)
sys.exit(1 if errors else 0)
```

## Pitfalls

- Some harnesses use the word "rules" for a different concept (for example, command execution policy). Confirm that a "rules" feature holds instructions before you put conventions there.
- Some harnesses stop reading instruction files after a byte limit. Keep the canonical instruction file under 120 lines.
- When two skills directories contain the same skill name, a harness can load both copies or select one of them. A symlink keeps the copies identical, so the result is the same.
- Do not generate files for harnesses that the user did not select. Each unused file is noise for the humans and agents that read the repository.
