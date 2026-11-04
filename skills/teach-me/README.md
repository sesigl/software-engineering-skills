# teach-me

Teaches a topic that the learner does not know yet, like a warm and patient teacher. The agent starts with the problem that the topic solves. Then it zooms in one level at a time, in plain English, with one running example. It checks understanding with a teach-back and offers a quiz at the end.

## Why

A model that is asked to "explain X" usually writes one long answer with every detail at once. The learner reads it, says "makes sense", and forgets most of it. This skill teaches in small steps that the learner controls. It asks the learner to explain the topic back, because an explanation proves understanding and "makes sense" does not.

## How It Works

```text
Step 1: Warm start          Says the plan. Asks only what the context does not tell yet:
        │                   familiarity, goal, and a one-sentence guess ("no clue" is fine).
        ▼
Step 2: Zoom in             One level per message, wide to close:
        │                   Level 0 the problem -> Level 1 the big idea and a map of the parts
        │                   -> Level 2 the parts -> deeper levels as the goal needs.
        │                   Recent or version-specific topics: research current sources first
        │                   (references/research.md).
        ▼
Step 3: Teach-back          The learner explains it back with their own example. The agent
        │                   names what is right and re-explains only the main gap from a new angle.
        ▼
Step 4: Quiz offer          A short quiz, one question per message, with new scenarios
                            (references/quiz.md). Or a short summary and a review suggestion.
```

## Example Prompts

```text
/teach-me BM25
```

```text
Teach me Kubernetes operators from scratch. I have no idea how they work.
```

```text
I want to understand what is new in Java 27. I know Java 21 well.
```

## Evals

Each case runs with and without the plugin. Each case is one turn of the lesson: later steps put the earlier lesson into the prompt. The cases are in [`evals/teach-me/`](../../evals/teach-me/), and the portable copy is in [`evals/evals.json`](evals/evals.json).

| Case | What it checks | Delta |
| :--- | :--- | ---: |
| `warm-start-asks-before-teaching` | For a bare "Teach me Java 25", says the plan, asks about familiarity and goal, invites a guess, and waits instead of writing a lecture. | pending |
| `zooms-in-from-the-problem-with-a-work-example` | When the learner already gave the context, skips the questions, starts with the problem (not the solution), uses the learner's own shoe-shop example, and teaches one short level. | pending |
| `teach-back-finds-and-fixes-a-gap` | When the learner's explanation has a mistake, names what is right, corrects the one mistake from a new angle, and asks a smaller follow-up question instead of moving on. | pending |
| `quiz-asks-one-question-at-a-time` | Loads the quiz guide and asks only one question, in a new scenario, that needs understanding and not only memory. | pending |
| `checks-current-sources-for-a-recent-topic` | For a recent topic (Java 27), loads the research guide and names an official source for its facts, or says clearly that its knowledge may be out of date, and marks feature status. | pending |

The per-assertion pass rates and the findings are in [`evals/RESULTS.md`](../../evals/RESULTS.md#teach-me).
