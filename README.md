# Software Engineering Skills

Curated, high-signal skills for AI coding agents. Compatible out of the box with **Claude Code** (as a plugin marketplace), **OpenCode**, **Cursor**, **Codex**, **Windsurf**, and any harness that supports the [Agent Skills specification](https://agentskills.io).

---

## Available Skills

<!-- SKILLS:START -->
| Skill | Description | Invocation |
| :--- | :--- | :--- |
| [`agent-first-repo-setup`](skills/agent-first-repo-setup/) | Interviews you and scaffolds a Git repository for agent-first development with a lean `CLAUDE.md`, path-scoped `.claude/rules`, on-demand `.claude/skills`, a domain `GLOSSARY.md`, Gherkin feature specs, ADRs, a parameterized `Makefile`, fast system tests, and deterministic quality guardrails (Dryer, Crapper, Mutator). Targets Claude Code by default and adapts to other harnesses after it researches their conventions. | Model & User (`/agent-first-repo-setup`) |
| [`assisted-pr-review`](skills/assisted-pr-review/) | Guides you through a pull request as an interactive, step-by-step tour in the terminal, moving from system intent and architecture down to individual lines one stop at a time. | Model & User (`/assisted-pr-review`) |
<!-- SKILLS:END -->

Each skill folder has a `README.md` with a deep dive (why, how it works, example prompts) and a summary of its evals.

---

## Installation

### Option 1: Claude Code Plugin Marketplace (Recommended for Claude Code)

Run this command inside Claude Code (2.1.275 or later):

```bash
/plugin install software-engineering-skills --marketplace sesigl/software-engineering-skills
```

On older versions, run these commands instead:

```bash
# 1. Add this repository as a plugin marketplace
/plugin marketplace add sesigl/software-engineering-skills

# 2. Install the skills plugin
/plugin install software-engineering-skills
```

Or launch Claude Code with this repository loaded directly from a local clone:

```bash
claude --plugin-dir /path/to/software-engineering-skills
```

### Option 2: `skills` CLI (Claude Code, OpenCode, Cursor, Codex, Windsurf, Copilot)

Install all skills or select specific skills across any supported coding agent harness:

```bash
# Install all skills interactively
npx skills add sesigl/software-engineering-skills

# Install a specific skill globally for Claude Code or OpenCode
npx skills add sesigl/software-engineering-skills --skill assisted-pr-review -g
```

### Option 3: OpenCode

Copy or symlink the skills into your global OpenCode skills directory (`~/.config/opencode/skills/`) or project `.opencode/skills/` directory:

```bash
git clone https://github.com/sesigl/software-engineering-skills.git
ln -s "$(pwd)/software-engineering-skills/skills/assisted-pr-review" ~/.config/opencode/skills/assisted-pr-review
```

### Option 4: Direct Clone into `~/.claude/skills`

```bash
git clone https://github.com/sesigl/software-engineering-skills.git
cp -r software-engineering-skills/skills/* ~/.claude/skills/
```

---

## Repository Structure

```text
software-engineering-skills/
├── .claude-plugin/
│   ├── marketplace.json                  # Claude Code marketplace catalog
│   └── plugin.json                       # Claude Code root plugin manifest
├── .cursor-plugin/
│   └── plugin.json                       # Cursor plugin manifest
├── .github/
│   └── workflows/
│       └── validate.yml                  # CI validation for skills and manifests
├── scripts/
│   └── validate-skills.sh                # Local & CI validator: Agent Skills spec, manifests, skill READMEs
├── skills/
│   └── <skill-name>/                     # agent-first-repo-setup, assisted-pr-review
│       ├── SKILL.md                      # Primary skill steps and completion criteria
│       ├── README.md                     # Deep dive and eval summary for humans
│       ├── references/                   # Disclosed references, loaded on demand
│       └── evals/
│           └── evals.json                # Portable eval scenarios (skill-creator format)
├── evals/
│   ├── README.md                         # How to run and write plugin evals
│   ├── RESULTS.md                        # Latest recorded eval scores
│   └── <skill-name>/<case>/              # case.yaml, scaffold.sh, graders/ for `claude plugin eval`
├── CLAUDE.md                             # Concise repository instructions for agents
├── CONTRIBUTING.md                       # Skill authoring and review guidelines
├── LICENSE                               # MIT License
└── README.md
```

---

## Design Principles (Claude 5 / Opus 5.5 Ready)

Every skill in this repository is written for current frontier models (Claude Opus 5.5 and peer harnesses):

1. **Information Hierarchy & Progressive Disclosure**: `SKILL.md` holds only the ordered steps and rules needed on every run. Conditional reference material (such as GitHub API payload mechanics in `references/pending-review.md`) sits one level deep behind explicit context pointers and loads only when that branch runs.
2. **Checkable Completion Criteria**: Every step ends with an explicit, verifiable completion criterion to prevent premature completion.
3. **Positive Steering**: Instructions state the target behavior rather than listing prohibitions. Hard guardrails (such as keeping the working tree untouched and leaving GitHub reviews in `PENDING` state) include the reason behind the rule so the model generalizes accurately.
4. **Settled Multi-Turn State**: Interactive skills instruct the model to treat completed steps as settled unless the user asks to revisit them, keeping follow-up latency and token usage low.
5. **No-Op Pruning**: General software engineering knowledge that the base model already follows by default is omitted to minimize context load.

---

## Validating and Contributing

Run the validation script to check all skills and marketplace manifests before opening a pull request:

```bash
./scripts/validate-skills.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on authoring, testing, and submitting new skills.

---

## License

[MIT](LICENSE) © Sebastian Sigl
