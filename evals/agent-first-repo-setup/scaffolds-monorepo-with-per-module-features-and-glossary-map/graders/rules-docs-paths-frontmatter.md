---
type: regex
weight: 1
target: {source: file, path: claude-context/rules/docs-and-adrs.md}
pattern: '^-{3}\r?\n(?:[^\n]*\r?\n)*?paths:'
match: contains
---
