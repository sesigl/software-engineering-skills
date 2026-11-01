---
type: llm
weight: 2
focus: trace
---

In the trace, the agent runs `make check` after the last file change, that final run exits 0, and the run executes `scripts/check-agent-context`. A run that fails, is skipped, or is only claimed in prose without a command result does not pass.
