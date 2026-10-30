---
name: assisted-pr-review
description: Guides the user through a pull request as an interactive, step-by-step tour in the terminal, moving from system intent and architecture down to individual lines one stop at a time. Use when the user asks to review a PR together, says "assisted PR review", "pair review", "walk me through this PR", or wants to understand and critique a pull request interactively instead of receiving a one-shot review dump.
argument-hint: "[PR number, URL, or branch]"
license: MIT
author: Sebastian Sigl <akrillo89@gmail.com>
attribution: Layering, review notes, and clean-stop rules adapted from https://github.com/thekie/pr-walkthrough-skill
---

# Assisted PR Review

The user is the reviewer. You are the guide on a **guided tour** of the pull request: you inspect the change first, design a logical route through the diff, and present it one **stop** at a time in the terminal. The goal is human understanding and judgment so the reviewer makes their own decisions.

Keep the working tree untouched during the tour so the reviewer evaluates the author's exact diff.

## Step 1 — Send a scout

Launch one background subagent as a **scout** to inspect the pull request while you read the overview. Use `gh` (`gh pr view`, `gh pr diff`), `git diff`, or available GitHub and issue-tracker MCP tools.

The **scout**:

1. Reads the PR title, description, commit messages, and any linked issue or ticket, then states the intended behavior in 3–5 sentences.
2. Reads the full diff and compares the implementation against the intended behavior.
3. Reports only high-confidence behavioral problems: broken contracts, missing requirements from the ticket, regressions, data loss, concurrency hazards, or security flaws. Each finding includes `file:line`, what happens at runtime, and the evidence in the code.

While the scout runs, read the PR metadata and changed file list yourself. Wait for the scout to finish before starting Step 2, because its findings determine which stops need the closest attention.

Completion criterion: the scout has returned the intended behavior, the list of high-confidence mismatches (or confirmed none exist), and every changed file is accounted for by role (production, test, configuration).

## Step 2 — Show the map

Present a compact overview in plain language:

- **Why**: the problem the PR solves, in 1–2 sentences.
- **What**: the core idea of the solution, in 2–3 sentences, without code snippets.
- **Route**: the numbered **stops** of the tour. Group line ranges by concern rather than by file. Separate unrelated changes in the same PR into distinct stop groups. Order foundations (schemas, types, ports, contracts) before the code that depends on them. Mark stops where the scout or your inspection found a likely risk with `[!]`.

Keep each stop to one line: `file:lines` and a short label, plus a risk label of at most 8 words for `[!]` stops. Keep code snippets, findings, and assessments out of the map; they belong to the stop itself in Step 3. A long map turns the tour into a one-shot review dump.

Ask whether the reviewer wants to start with Stop 1 or adjust the route (reorder, merge, or skip stops). End your turn and wait for their reply.

Completion criterion: every changed production concern belongs to a stop on the route, every scout finding is mapped to a stop, and the reviewer has confirmed or adjusted the route.

## Step 3 — Walk the stops, one per turn

Present one **stop** per message:

1. **Context**: state in plain words what this part does and how it connects to the previous stop.
2. **Code**: show only the lines that matter (`file:line` with a short snippet).
3. **Verification**: if a test covers this behavior, show the relevant assertion and state what it proves. If no test covers it, state that explicitly.
4. **Assessment**: measure the code against the intended behavior. Call out any scout finding, unrequested behavior, skipped edge case, test that only asserts the implementation, or misleading name. Verify every claim in the code before stating it, and state your confidence. When a stop has no issues, state that it is clean in one sentence; invented nits erode trust in the tour.
5. **Pause**: end your turn with a short prompt (`Questions, or next stop?`) and wait for the reviewer.

During the walkthrough:

- When the reviewer flags an issue or decision, record it as a **review note** (`file:line` plus a self-contained explanation that a reader outside this session will understand) and continue without debating the wording.
- When the reviewer asks a question, investigate the codebase or tests to answer it completely before moving on.
- Once a stop is complete, treat it as settled and focus on the current stop unless the reviewer asks to revisit it or a later stop exposes a contradiction.

Completion criterion: every stop on the route has been presented or explicitly skipped by the reviewer.

## Step 4 — Close the tour

When the final stop is complete, present:

- All captured **review notes**, grouped by file under one `file` heading each, including notes captured in the current turn.
- Any remaining **scout** findings that were not already turned into review notes.

Review the list together: a later stop may have resolved an earlier note, or a note may need sharper phrasing. Ask which notes to keep, merge, reword, or drop.

Then ask whether the reviewer wants to post the final notes as draft PR comments on GitHub. A request to "put it on GitHub" earlier in the tour does not replace this confirmation, because the reviewer has not yet seen the final list. In the same message, state that the review will be created in **PENDING** state and not submitted as APPROVE, REQUEST_CHANGES, or COMMENT, so the reviewer stays in control of what the author sees. End your turn and wait.

When the reviewer confirms the final list, read [`references/pending-review.md`](references/pending-review.md) and create the **pending** review so the reviewer can inspect and submit it themselves.

Completion criterion: every scout finding has been surfaced, every review note has been confirmed or dropped by the reviewer, and any requested GitHub review is saved in pending state.

## Communication style

Write in clear, direct technical English: short sentences, one idea per sentence, literal phrasing. Explain domain-specific terms the first time they appear. Keep each turn to a single stop so the review stays a conversation.
