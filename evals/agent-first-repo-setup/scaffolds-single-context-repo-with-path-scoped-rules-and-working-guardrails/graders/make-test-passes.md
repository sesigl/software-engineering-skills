---
type: llm
weight: 2
focus: trace
---

In the trace, the agent runs `make test` after the last file change, and that final run exits 0 (all checks and the @SPEC-001 system test pass). A run that fails, is skipped, or is only claimed in prose without a command result does not pass.
