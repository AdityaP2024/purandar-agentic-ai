# ai-agent-backend

Backend stack plugin of the Thinkitive AI agent suite:

- **Agent**: backend-springboot — implements approved tech specs
  (Java/Spring Boot)
- **Skill**: spring-boot — engineering standards the agent enforces

Requires the `ai-agent` core plugin in the same repo — the agent loads the
core's shared-standards, hipaa, and audit-logging skills and is launched by
the core's /implement command. Enable both in a backend code repo. See the
repository root README and docs/ for the full suite documentation.
