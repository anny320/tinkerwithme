# Skill attribution

The verification skills in this directory are adapted from the **pstack** plugin
by Cursor, released under the MIT License.

- Source: https://github.com/cursor/plugins/tree/de8ee15dd1194627d21eb5fcd41cb1873208dabb/pstack/skills
- Skills adapted: `create-verification-skill`, `maintain-verification-skill`
  (plus the `references/feature-map-example/` worked example).
- Changes made for this repo: converted from Cursor (`.cursor/skills/`) to
  Claude Code (`.claude/skills/`) layout and frontmatter, and repointed all
  generated-skill paths to `.claude/skills/verify-<app>/`.

pstack also ships `create-formal-verification-skill` and
`maintain-formal-verification-skill` (TLA+/model-checker/prover based). Those
were intentionally not installed here; they can be added later if the codebase
grows concurrency, state-machine, or invariant-heavy code worth model-checking.
