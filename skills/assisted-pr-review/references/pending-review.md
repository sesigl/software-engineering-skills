# Creating a Pending GitHub Review

Disclosed reference for Step 4 of [`assisted-pr-review`](../SKILL.md). Load this file only when the reviewer wants to post their finalized review notes to GitHub.

## Contents

- Guardrail: leave the review pending
- Phrasing review comments
- Posting a pending review via `gh api`

## Guardrail: leave the review pending

Create the review without an `event` field (`APPROVE`, `REQUEST_CHANGES`, or `COMMENT`). Omitting `event` keeps the review in `PENDING` state on GitHub so the reviewer can inspect, edit, or delete each comment in the GitHub UI before submitting.

## Phrasing review comments

Write each comment so it reads like a thoughtful colleague:

- **Brief and direct**: 1–3 sentences per inline comment. State the issue or question without preamble.
- **Ask when intent is uncertain**: if a behavior might be deliberate, phrase the note as a question (`Is PAUSED included here on purpose? The ticket only mentions ACTIVE ads.`).
- **State blockers plainly**: when a line causes a bug or breaks a contract, state the exact runtime failure (`This throws NullPointerException when user.profile() is null.`).
- **Prefix minor suggestions**: mark non-blocking improvements with `nit:` (`nit: extract this magic timeout into a named constant.`).
- **Plain punctuation**: use commas, periods, or parentheses instead of em dashes or AI-style headers (`**Suggestion:**`).

## Posting a pending review via `gh api`

1. Resolve the repository owner, name, PR number, and head commit SHA:

```bash
gh pr view <pr-number> --json number,headRefOid,headRepository,headRepositoryOwner
```

2. Write the review payload to a temporary JSON file (for example `/tmp/pr-review-<pr-number>.json`). Omit the `event` key so the review stays `PENDING`:

```json
{
  "commit_id": "<headRefOid>",
  "body": "",
  "comments": [
    {
      "path": "src/main/Example.java",
      "line": 42,
      "side": "RIGHT",
      "body": "Is `PAUSED` included here on purpose? The ticket only mentions `ACTIVE`."
    }
  ]
}
```

3. Create the pending review:

```bash
gh api \
  --method POST \
  /repos/<owner>/<repo>/pulls/<pr-number>/reviews \
  --input /tmp/pr-review-<pr-number>.json
```

If an inline line number lies outside the diff hunk, GitHub returns `422 Unprocessable Entity`. In that case, attach the comment to the nearest changed line in the same file and note the exact target line in the comment body.
