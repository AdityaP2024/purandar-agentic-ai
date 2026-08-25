# ai-agent (core)

The core plugin of the Thinkitive AI agent suite. Ships everything except the
stack implementers:

- **Agents**: doc-analyst, gap-analyst, jira-researcher, spec-writer,
  hipaa-compliance, agent-auditor
- **Commands**: /setup-repo, /onboard-project, /gap-analysis, /research-ticket,
  /create-spec, /implement, /implement-batch, /hipaa-check, /agent-audit
- **Skills**: shared-standards, hipaa, audit-logging
- **Templates**: the locked output contracts (brief, gap report, research,
  tech spec, decisions log)
- **Hooks**: git-write guard, secret/PHI write guard, observability event
  logger, workspace scaffolder
- **Scripts**: xlsx-extract.py, aggregate-metrics.sh

Enable it in every repo that uses the suite. Implementation needs a stack
plugin beside it: `ai-agent-backend` (Java/Spring Boot) or `ai-agent-frontend`
(React/TypeScript). See the repository root README and docs/ for the full
suite documentation.
