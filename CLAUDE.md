# Software Engineering Skills Repository

This repository hosts reusable AI coding agent skills in `skills/<skill-name>/SKILL.md` and exposes them as a Claude Code plugin marketplace.

## Verification

After adding or modifying any skill or manifest, run:

```bash
./scripts/validate-skills.sh
```

## Gotchas

- Bump the plugin version for every change that users install (skills, references, manifests). Users get updates only when the version changes. Use semantic versioning: patch for fixes, minor for new or improved skills, major for breaking changes.
- Set the same version in all four places: `.claude-plugin/marketplace.json` (top-level `version` and the plugin entry `version`), `.claude-plugin/plugin.json`, and `.cursor-plugin/plugin.json`.
- List skills only in `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json`. Do not add `skills` or `strict: false` to the marketplace entry: Claude Code rejects a plugin when both manifests specify components.
- Keep `SKILL.md` files concise and move optional or branch-specific reference material one level deep into `skills/<skill-name>/references/`.
- Write all documentation and skills in clear, literal technical English (ASD-STE100).
