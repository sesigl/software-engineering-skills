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
