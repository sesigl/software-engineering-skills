---
type: regex
weight: 1
target: files
pattern: '(^|\n)(AGENTS\.md|GEMINI\.md|\.agents/|\.cursor/|\.gemini/|\.github/instructions/|\.github/copilot-instructions\.md)'
match: not_contains
---
