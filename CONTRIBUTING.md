# Contributing Skills

Contributions that add new software engineering skills or sharpen existing ones are welcome.

## Skill Authoring Principles

Skills in this repository follow Generation 5 agentic skill design and Claude Opus 5.5 prompting practices:

1. **Earn every token (No-Op Test)**: Before adding a rule, verify that the model gets the behavior wrong without the skill. Omit general software engineering advice that frontier models already do by default.
2. **Information Hierarchy**:
   - Keep `SKILL.md` under 500 lines (aim for under 150 lines).
   - Put ordered **steps** and universal rules in `SKILL.md`.
   - Move branch-specific or detailed reference material into `references/<topic>.md` (maximum one directory level deep from `SKILL.md`).
3. **Sharp Completion Criteria**: End each step with a checkable, exhaustive completion criterion (`Completion criterion: ...`).
4. **Positive Steering**: State what the agent should do instead of what it must not do. Reserve prohibitions for high-cost guardrails and state the reason for each guardrail.
5. **Clear Technical English**: Write in ASD-STE100 Simplified Technical English: short sentences, literal phrasing, one idea per sentence.

## Adding a New Skill

1. Create a folder under `skills/<skill-name>/` using lowercase letters, numbers, and hyphens.
2. Add `skills/<skill-name>/SKILL.md` with required YAML frontmatter:
   ```yaml
   ---
   name: <skill-name>
   description: <Third-person summary of what the skill does + "Use when..." trigger branches, max 1024 chars>
   license: MIT
   author: <Your Name>
   ---
   ```
3. Add at least three evaluation cases in `skills/<skill-name>/evals/evals.json`. Add the same cases as `claude plugin eval` cases in `evals/<skill-name>/<case-name>/`, run them, and record the scores in `evals/RESULTS.md`. See `evals/README.md`.
4. Add `skills/<skill-name>/README.md` with this structure (`./scripts/validate-skills.sh` checks it):
   ```markdown
   # <skill-name>

   <One paragraph: what the skill does.>

   ## Why
   ## How It Works
   ## Example Prompts
   ## Evals
   ```
   You can add more sections, for example `## Prerequisites`. The `## Evals` section names every case in `evals/<skill-name>/` and links to `evals/RESULTS.md`.
5. Register `./skills/<skill-name>` in:
   - `.claude-plugin/plugin.json`
   - `README.md` (in the Available Skills table)
6. Bump the `version` field in `.claude-plugin/marketplace.json`, `.claude-plugin/plugin.json`, and `.cursor-plugin/plugin.json`.
7. Run the validator:
   ```bash
   ./scripts/validate-skills.sh
   ```

## Review Checklist

- [ ] Each rule changes behavior compared with the model's default.
- [ ] Absolute rules are used only for high-risk operations, each with a stated reason.
- [ ] `name` and `description` obey platform constraints (`name` <= 64 chars, `description` <= 1024 chars, third-person, no XML tags).
- [ ] `SKILL.md` is under 500 lines and references are at most one level deep.
- [ ] `evals/evals.json` contains at least three evaluation scenarios.
- [ ] `README.md` has the required sections, and `## Evals` names every eval case.
- [ ] `./scripts/validate-skills.sh` passes with zero failures.
