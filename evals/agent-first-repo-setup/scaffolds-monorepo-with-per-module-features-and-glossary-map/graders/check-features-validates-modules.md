---
type: llm
weight: 2
focus: trace
---

In the trace, the agent runs scripts/check-features (directly or through a make target) after the last file change, the run exits 0, and the script checks .feature files in both the ordering and inventory modules with unique @SPEC tags.
