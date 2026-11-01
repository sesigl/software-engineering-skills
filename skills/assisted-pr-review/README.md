# assisted-pr-review

Guides you through a pull request as an interactive tour in the terminal. You are the reviewer, and the agent is your tour guide. The agent prepares a logical route through the diff and shows it to you one concern at a time.

## Why

One-shot AI code reviews show all findings at once. The human reviewer loses the thread of the change and then approves without reading or ignores the output. This skill keeps the human in control: the agent explains, and you decide.

## How It Works

```text
Step 1: Send a scout        Background subagent compares PR intent & ticket against the full diff
        │                   to find high-confidence behavioral defects while you read the overview.
        ▼
Step 2: Show the map        Presents Why (1–2 sentences), What (2–3 sentences), and a numbered
        │                   Route of stops ordered from foundations (schemas, types, contracts)
        │                   to dependents. Risky stops are marked with [!]. Waits for your OK.
        ▼
Step 3: Walk the stops      One stop per turn:
        │                   1. Context — what this part does and how it connects to the last stop
        │                   2. Code — focused file:line snippets
        │                   3. Verification — what the tests prove (or what coverage is missing)
        │                   4. Assessment — behavioral mismatches, edge cases, or a 1-line "clean" verdict
        │                   5. Pause — waits for your questions or review notes before moving on
        ▼
Step 4: Close the tour      Summarizes your captured review notes and any remaining scout findings.
                            Optionally posts your approved notes to GitHub as a PENDING review.
```

## Example Prompts

```text
/assisted-pr-review 142
```

```text
Walk me through PR #142 with assisted-pr-review.
```

```text
Pair review https://github.com/org/repo/pull/142 with me one stop at a time.
```

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) authenticated (`gh auth status`), or a configured GitHub MCP server, when you review remote GitHub pull requests or post pending review drafts.
- Without a network, the skill works with `git diff` on local branches.

## Evals

Each case runs with and without the plugin. The cases are in [`evals/assisted-pr-review/`](../../evals/assisted-pr-review/), and the portable copy is in [`evals/evals.json`](evals/evals.json).

| Case | What it checks | Delta |
| :--- | :--- | ---: |
| `starts-with-scout-and-map-not-dump` | Shows a short Why/What/Route map, orders foundations first, and waits for confirmation. | +0.92 |
| `single-stop-pacing-and-clean-stop-honesty` | Shows only one stop with snippet and test evidence, and calls a clean stop clean without invented nits. | +0.17 |
| `captures-review-note-and-closes-with-pending-review` | Records a self-contained note, closes with a summary, and asks for confirmation before it creates a PENDING review. | +0.42 |

The per-assertion pass rates and the findings are in [`evals/RESULTS.md`](../../evals/RESULTS.md#assisted-pr-review).
