# ai-agent-frontend

Frontend stack plugin of the Thinkitive AI agent suite:

- **Agent**: frontend-react — implements approved tech specs
  (React/TypeScript)
- **Skill**: react — engineering standards the agent enforces. A router
  card (`skills/react/SKILL.md`) holding the always-on rules and a routing
  table, over twelve on-demand reference files in `skills/react/references/`
  (theme and tokens, state and persistence, async and race conditions, forms
  and contract, error handling, responsiveness, accessibility, performance,
  code quality, testing, cross-browser, security and gating). Only the router
  loads on every run; reference files are read when their triggers match, so
  a styling change does not pay for the testing and accessibility rules.

  The standards pin no library, version, or directory layout: every rule
  either names an outcome or defers to what the consuming project already
  does. Where a project lacks the infrastructure a rule names, the outcome
  still holds and the gap is reported — the agent never builds framework
  inside a feature ticket.

Requires the `ai-agent` core plugin in the same repo — the agent loads the
core's shared-standards and hipaa skills and is launched by the core's
/implement command. Enable both in a frontend code repo. See the repository
root README and docs/ for the full suite documentation.
