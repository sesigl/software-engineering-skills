# Eval Results

## assisted-pr-review

- Date: 2026-10-30
- Claude Code: 2.1.314
- Model: claude-opus-5-5 (agent), haiku (judge, 3 votes per grader)
- Runs: 3 per case per arm (with plugin / without plugin)
- Command: `claude plugin eval . --scaffold --allow-tools "Bash(git:*)" --runs 3 -j 4 --no-publish --threshold 0`

| Case | With | Without | Delta |
| :--- | ---: | ---: | ---: |
| starts-with-scout-and-map-not-dump | 1.00 | 0.08 | +0.92 |
| single-stop-pacing-and-clean-stop-honesty | 0.83 | 0.67 | +0.17 |
| captures-review-note-and-closes-with-pending-review | 0.83 | 0.42 | +0.42 |

### Per-Assertion Pass Rate (with / without)

**starts-with-scout-and-map-not-dump**

| Assertion | With | Without |
| :--- | ---: | ---: |
| Short map, not a full review | 3/3 | 0/3 |
| Why, What, and numbered Route | 3/3 | 0/3 |
| Foundation before dependent layers | 3/3 | 1/3 |
| Asks to confirm or adjust the route | 3/3 | 0/3 |

**single-stop-pacing-and-clean-stop-honesty**

| Assertion | With | Without |
| :--- | ---: | ---: |
| Presents only Stop 1 | 2/3 | 3/3 |
| Shows snippet and what the test proves | 3/3 | 2/3 |
| States the stop is clean without invented nits | 2/3 | 0/3 |
| Asks for questions or permission to continue | 3/3 | 3/3 |

**captures-review-note-and-closes-with-pending-review**

| Assertion | With | Without |
| :--- | ---: | ---: |
| Self-contained note with file, line, and failure | 2/3 | 2/3 |
| Closing summary grouped by file | 3/3 | 0/3 |
| No GitHub post before confirmation | 3/3 | 3/3 |
| Asks to confirm and states PENDING review | 2/3 | 0/3 |

### Findings

1. The skill has a strong effect on tour structure: a short Why/What/Route map, foundation-first ordering, and a confirmation pause.
2. Before posting, the agent asks for confirmation and states that the review stays PENDING (2/3). The baseline does this 0/3.
3. The remaining failures are single judge votes on borderline wording. The single-stop case has the smallest delta, because the baseline already paces one stop per turn when the prompt names Stop 1.

### History

- Run 1: the sandbox was empty, so both arms scored about 0. Fix: `scaffold.sh` builds a fixture repository.
- Run 2: the agent never asked for confirmation before posting (0/3), and the map was too long (1/3). Fix: Step 2 and Step 4 of `SKILL.md`.
- Run 3: the fixture was missing `Redis.ts`, `EventBus.ts`, and `FakeRedis.ts`, so the agent correctly reported missing files. Fix: the files are now in the fixture base commit.

## agent-first-repo-setup

- Date: 2026-11-01
- Claude Code: 2.1.316
- Model: claude-opus-5-5 (agent), sonnet (judge, 3 votes per grader)
- Runs: 3 per case per arm (with plugin / without plugin)
- Command: `claude plugin eval . --tag agent-first-repo-setup --scaffold --allow-tools Bash Write Edit --judge-model sonnet --runs 3 -j 4 --no-publish --threshold 0 --max-cost-usd 60`
- Duration and cost: 25 minutes, $26.54

| Case | With | Without | Delta |
| :--- | ---: | ---: | ---: |
| starts-with-focused-interview-and-recommended-defaults | 0.89 | 0.50 | +0.39 |
| scaffolds-single-context-repo-with-path-scoped-rules-and-working-guardrails | 1.00 | 0.17 | +0.83 |
| scaffolds-monorepo-with-per-module-features-and-glossary-map | 1.00 | 0.50 | +0.50 |

### Per-Assertion Pass Rate (with / without)

**starts-with-focused-interview-and-recommended-defaults**

| Assertion | With | Without |
| :--- | ---: | ---: |
| No files before confirmation | 3/3 | 3/3 |
| Asks for GLOSSARY.md domain terms | 3/3 | 1/3 |
| Proposes a fast system-test harness (PGlite, SQLite, fakes) | 3/3 | 0/3 |
| Names quality-signal defaults (duplication, CRAP, mutation) | 2/3 | 0/3 |
| Each question includes a recommended default | 2/3 | 2/3 |
| Ends the turn with open questions | 3/3 | 3/3 |

**scaffolds-single-context-repo-with-path-scoped-rules-and-working-guardrails**

| Assertion | With | Without |
| :--- | ---: | ---: |
| CLAUDE.md exists | 3/3 | 3/3 |
| CLAUDE.md has the three pillars | 3/3 | 0/3 |
| GLOSSARY.md with Order, LineItem, and Avoid lists | 3/3 | 0/3 |
| docs/README.md exists | 3/3 | 0/3 |
| docs/adr/0001-*.md exists | 3/3 | 1/3 |
| Seed .feature file in features/ | 3/3 | 0/3 |
| rules/testing.md has `paths:` frontmatter | 3/3 | 0/3 |
| rules/features.md has `paths:` frontmatter | 3/3 | 0/3 |
| system-testing skill names FakePaymentGateway, Dryer, Crapper, Mutator, `:memory:` | 3/3 | 0/3 |
| domain-modeling skill exists | 3/3 | 0/3 |
| feature-development skill exists | 3/3 | 0/3 |
| scripts/check-features, check-traceability, check-quality exist | 3/3 | 0/3 |
| Final `make test` exits 0 (weight 2) | 3/3 | 2/3 |

**scaffolds-monorepo-with-per-module-features-and-glossary-map**

| Assertion | With | Without |
| :--- | ---: | ---: |
| GLOSSARY-MAP.md exists | 3/3 | 3/3 |
| ordering and inventory GLOSSARY.md exist | 3/3 | 3/3 |
| ordering and inventory features/*.feature exist | 3/3 | 0/3 |
| Makefile supports `MODULE=` | 3/3 | 3/3 |
| rules/features.md has `paths:` frontmatter | 3/3 | 3/3 |
| rules/docs-and-adrs.md has `paths:` frontmatter | 3/3 | 0/3 |
| check-features runs, exits 0, and covers both modules (weight 2) | 3/3 | 0/3 |

### Findings

1. With the skill, both scaffold cases pass every assertion in 3 of 3 runs, including a passing `make test` in the sandbox.
2. In the interview, the skill adds a concrete fast test harness (3/3 against 0/3) and quality-signal defaults (2/3 against 0/3). The skill asks 2 to 4 questions per round, so the quality thresholds can come in the second round. The grader accepts a preview of the next round.
3. Without the skill, the agent also builds a working repository (`make test` 2/3). Most baseline failures are conventions that the skill defines: file names (`GLOSSARY.md`, `scripts/check-*`, `docs/adr/0001-*`), the three-pillar principles, and the project skills. The delta measures how well the agent follows the skill's blueprint, not general code quality.
4. The monorepo baseline creates the glossaries and `MODULE=` support, but no `<module>/features/*.feature` files in any run (0/3). So its check-features grader also fails (0/3).

### Sandbox Limits

The eval sandbox blocks writes to `.claude/`, has no network, and cannot run the `/usr/bin` Xcode shims. The case prompts describe the workarounds. See `README.md`.

### History

- Smoke run: every write to `.claude/` was denied, and `make test` could not run in either arm. Fix: the agent writes to `claude-context/`, `scaffold.sh` prepares `.venv/`, and the prompt names the CommandLineTools `make` and `git`.
- Smoke run: two interview graders were too strict. Fix: the quality-threshold grader accepts a preview of the next round, and "defaults and waits" became two graders.
- During this run, the `SKILL.md` intro changed: it no longer says that `make test` passes out of the box. Some runs used the old intro. Step 5 did not change.
