# Plugin Evals

This directory holds the behavioral eval suite for `claude plugin eval`. Each skill has one folder. Each case has its own folder:

```text
evals/
└── <skill-name>/
    └── <case-name>/
        ├── case.yaml          # Prompt, tools, run count, scaffold script
        ├── scaffold.sh        # Builds the fixture repository in the agent's working directory
        └── graders/*.md       # One grader per assertion (llm or tool_used)
```

The eval dir is the default `evals/` at the plugin root. `claude plugin eval` rejects eval cases inside `skills/`, because `skills/` is a loaded plugin component directory.

`skills/<skill-name>/evals/evals.json` is the portable, harness-neutral source of each scenario (Agent Skills / skill-creator format). Keep the prompts and assertions in `evals.json` and in `evals/<skill-name>/` synchronized.

## Run the Suite

```bash
claude plugin eval . --scaffold --allow-tools "Bash(git:*)" --runs 3 -j 4 --no-publish --threshold 0
```

- `--scaffold` runs each case's `scaffold.sh`. The script creates a local git repository with a `main` base branch and a `pr-<n>` branch. Without it, the working directory is empty and the agent has no code to review.
- The default ablation runs each case with the plugin and without it (baseline). The report shows the score delta.
- Raw results go to `evals/results/<timestamp>/`. This directory is git-ignored. Record a summary in `RESULTS.md` instead.
- Each case is one turn. To test a later step of a multi-step skill, write the earlier steps into the prompt as context.

## Write Graders

- A grader of `type: llm` sees only the last message by default. Write criteria that the last message can prove.
- Use `type: tool_used` (with `input_match`) to check file reads or tool calls, for example that the agent loaded a `references/` file.
- The `Skill` `tool_used` grader is a plugin-fired indicator. It is not part of the score under ablation.
- The agent has no GitHub remote. Grade what the agent does before an outward action (for example, asking for confirmation), not the action itself.

## Record Results

After a run that changes scores, update `RESULTS.md` with the date, Claude Code version, model, run count, and per-assertion pass rates for both arms.
