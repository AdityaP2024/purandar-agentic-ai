# Getting Started

The practical guide to installing the ai-agent plugin, onboarding your first project, and
taking your first ticket from research to a compliance-checked implementation. For what each
agent knows and where its authority stops, see `docs/AGENT-CATALOG.md`.

## 1. Prerequisites

- **Claude Code installed** and working in your terminal.
- **GitHub access to the plugin repository.** Installs use your existing GitHub credentials;
  if you can clone the repo, you can install the plugin.
- **Atlassian connector authorized** (claude.ai connector settings). This is the plugin's only
  Jira access path, and it is per-user OAuth — no shared credentials, no stored tokens.
  - Needed for: `/research-ticket`, and `/create-spec` in inline mode (when no
    `docs/tickets/<KEY>/research.md` exists).
  - NOT needed for: `/onboard-project`, `/implement`, or `/hipaa-check`. You can onboard a
    project and implement approved specs without the connector.
- **python3 on PATH** — OPTIONAL. Needed only by `/gap-analysis`, whose workbook extractor is
  python3 standard library alone (no packages to install); every other command runs without it.
- **Figma connector authorized** (claude.ai connector settings) — OPTIONAL. Needed only when the
  project's designs live behind Figma links (in `docs/input-specs/` documents or on Jira tickets). Same
  access model as Atlassian: per-user OAuth, read-only, no shared credentials. Without it the
  pipeline still runs — agents list each Figma link as an inaccessible source and ask for the
  referenced frames exported as PNG/PDF instead; they never guess design intent from a URL.

## 2. Install the plugin

### Team-wide (recommended)

Commit this once to the consuming project repo:

```json
// .claude/settings.json
{
  "extraKnownMarketplaces": {
    "purandar-ai": {
      "source": { "source": "github", "repo": "AdityaP2024/purandar-agentic-ai" }
    }
  },
  "enabledPlugins": {
    "ai-agent@purandar-ai": true
  }
}
```

Every developer who opens the project in Claude Code is prompted to install the plugin
automatically.

### Manual (trying it out, or personal cross-project use)

```
/plugin marketplace add AdityaP2024/purandar-agentic-ai
/plugin install ai-agent@purandar-ai
```

Updates never land silently: pick up new plugin versions by running
`/plugin marketplace update` when you choose to.

### Safety hooks (shipped with the plugin)

Installing the plugin also activates two `PreToolUse` safety hooks in every session — harness-level
enforcement of contracts the agents already follow at the prompt level:

- **Git-write guard** (`Bash` commands): denies `git commit`, `git push`, tag creation, and
  `gh pr create/merge` before they run. The developer commits; the plugin never does. Read-only
  git (`status`, `diff`, `log`, `tag -l`) always passes.
- **Secret/PHI write guard** (`Write`/`Edit`): denies any file write whose content matches real
  token shapes (GitHub, Atlassian, Slack, AWS, generic sk- API keys, private-key blocks) or
  SSN-shaped values, before it reaches disk. The blocked values are never echoed back.

Both hooks need `jq` on the PATH (standard on most dev machines; `brew install jq` /
`apt install jq` otherwise). Without `jq` they fail open — the agents' prompt-level rules still
apply, but the mechanical backstop is inactive.

## 3. First run on a project

Do this once per project:

1. **Drop the project documents into `docs/input-specs/`.** The folder is created for you —
   a SessionStart hook scaffolds `docs/input-specs/` and `docs/output-specs/` (each with a
   README saying what belongs in it) the first time anyone opens a session in the repo, so
   nobody creates them by hand. Add the software requirements
   specification and any related project documents: meeting minutes (MOMs), interface control
   documents, data dictionaries, and the project's Figma design links (a document listing the
   URLs, or minutes that carry them — links are followed through your Figma connector, or
   requested as PNG/PDF frame exports without it). Make sure meeting minutes carry their dates:
   when dated minutes and the SRS disagree, the latest dated source wins. Readable
   formats: markdown, plain text, PDF, images. Proprietary binary formats (word-processor
   files and the like) are reported as skipped with a conversion request — export those to
   PDF, markdown, or plain text. The one exception is `.xlsx`: spreadsheet workbooks here are
   treated as your module-wise user stories — inputs to `/gap-analysis` (see below), never
   sources the brief is distilled from.
2. **Run `/onboard-project`.** It starts with a hygiene sweep of stale user-level agents in
   `~/.claude/agents/` — you choose which to disable (files are moved aside, never deleted).
   If anything was disabled, the command stops and asks you to start a fresh session and rerun,
   because already-loaded agent definitions only unload in a new session; a clean machine flows
   straight through. Then the doc-analyst agent reads every document completely and
   distills them into `docs/output-specs/PROJECT_BRIEF.md` — the operational brief every other
   agent reads instead of the originals — and scaffolds `docs/decisions.md` if it does not
   exist. If user-story `.xlsx` workbooks are in the documents directory, **gap analysis runs
   automatically right after the brief is written** (see below) — you do not run a separate
   command for the first pass.
3. **Review the Compliance Profile (Section 5 of `PROJECT_BRIEF.md`) now.** This matters
   because the pipeline is fail-closed: until you confirm the profile, every agent treats ALL
   person-related data in the system as PHI and applies the full HIPAA rule set. That is safe
   but noisy — an unconfirmed profile means maximum-caution handling everywhere. Resolve any
   rows marked "PHI (presumed — unconfirmed)" by answering the agent's open questions; an
   incomplete profile creates exposure, an overbroad one creates review noise.
4. **Commit `PROJECT_BRIEF.md` and `docs/decisions.md`.** You commit them yourself — the
   plugin never runs git. Everything the pipeline generates lives in the consuming repo,
   versioned alongside the code it explains.

`/onboard-project` runs once per project. Rerun it only after a material SRS change or to
update the brief's Where Implemented column — both paths return a diff gate report for your
approval before anything is overwritten.

### Validating your user stories (automatic, then iterate with /gap-analysis)

If your team writes module-wise user stories by hand, the plugin checks them against what the
SRS, meeting minutes, and Figma designs actually require:

1. **Drop the stories into `docs/input-specs/` as `.xlsx`** — one workbook, or one file per
   module — alongside the source documents, before onboarding. Module resolution is
   discovery-based: a `Module` column wins, else the sheet name, else the file name; column
   layout is read from each sheet's header row, so no fixed format is required.
2. **The first pass runs by itself.** As soon as `/onboard-project` writes the brief, it
   detects the workbooks and runs gap analysis automatically: the gap-analyst agent extracts
   every story, maps story modules to the brief's Module Briefs (Section 11) through the
   Domain Glossary, and compares both directions. You get the module status table and top gaps
   in chat, and the full consolidated module-wise report at
   `docs/output-specs/GAP_ANALYSIS.md` — every gap typed (MISSING-STORY, UNSOURCED-STORY,
   CONFLICT, PARTIAL) with both sides cited, so a disputed gap is checkable directly against
   the cited story and brief section. (Stories added only after onboarding? Run
   `/gap-analysis` once yourself — same result.)
3. **Iterate to ALIGNED.** Supply what the gaps name — missing stories, corrected stories, or
   updated source documents (a stale brief means rerunning `/onboard-project` first, which
   re-runs the gap analysis too) — and run `/gap-analysis` again. The report is regenerated
   whole each run and the chat verdict shows the delta ("14 gaps last run → 5 now"); converged
   is every module reading ALIGNED. Commit the final report alongside the brief — the
   converged, team-shared project knowledge.

It is report-only: gaps block nothing, and the agent never edits your stories, the brief, or
code — which side of a gap is right is always your call.

## 4. First ticket, end to end

1. **(Optional) `/research-ticket <KEY>`.** Full ticket excavation — description, every
   comment chronologically, linked issues, changelog, attachments read visually — into
   `docs/tickets/<KEY>/research.md`. Run it when the ticket is complex: a long or contentious
   comment thread, attachment-heavy design intent, a Sub-task whose requirements live on the
   parent, or a web of linked issues. For simple tickets, skip it: `/create-spec` does its own
   inline lightweight research.
2. **`/create-spec <KEY>`.** The spec-writer agent builds the locked-template tech spec at
   `docs/tickets/<KEY>/tech-spec.md` — every acceptance criterion mapped to existing or new
   code, the API contract pinned down field by field — and leaves it with Approval Status:
   DRAFT.
3. **The spec approval gate — yours alone.** Review the spec: Section 5 is what the
   implementers consume verbatim. Resolve any Section 12 open questions (fold each resolution
   into Section 3, then set Section 12 to NONE), confirm or correct any SPEC-WRITER-DERIVED
   acceptance criteria, then edit Section 13 yourself and flip the Approval Status line to
   exactly:

   ```
   APPROVED by {name} on {YYYY-MM-DD}
   ```

   with your real name and the real date. No agent or command ever writes APPROVED, and
   `/implement` refuses to run while the status is DRAFT.
4. **`/implement <KEY>`.** Backend work runs first (backend-springboot), then frontend
   (frontend-react) once its Section 7 cross-stack dependencies are marked RESOLVED. Before
   any code is written, each implementer stops at the **plan gate** and presents its plan —
   Files to Create / Files to Modify / Existing Code Reused / Risks — for your approval,
   revision, or abort. Test results are reported verbatim, failures included.
5. **`/hipaa-check` before the PR.** A standalone read-only compliance scan: PHI-leak findings
   ranked VIOLATION > RISK > BEST-PRACTICE with corrected code for every VIOLATION, plus a
   separate audit-coverage section. The agent writes no files and applies no fixes — corrected
   code appears inside the report for you (or a later `/implement` run) to apply.
6. **Review the diff and commit.** You review, you commit the code together with the
   `docs/tickets/<KEY>/` artifacts, you open the PR. The plugin never commits for you.

## 5. Smoke test

Validate a fresh install with this checklist:

- [ ] **Plugin visible.** Run `/plugin` and confirm `ai-agent` appears in the installed plugin
  list.
- [ ] **Workspace scaffolded.** In the consuming repo, a new session creates `docs/input-specs/`
  and `docs/output-specs/`, each containing a README that explains what belongs in it.
- [ ] **Gap-analysis preflight stops correctly.** With no brief (or no `.xlsx` in
  `docs/input-specs/`), `/gap-analysis` must stop with the actionable message naming the
  missing prerequisite — run `/onboard-project` first, or drop the story workbooks in — never
  an improvised comparison.
- [ ] **Onboarding preflight stops correctly.** In a repo where `docs/input-specs/` is missing or
  holds nothing but its scaffolded README, run `/onboard-project`. It must stop with the
  actionable message beginning "Onboarding cannot start: docs/input-specs/ does not exist or
  contains no documents." — including the instruction to create both workspace folders manually
  if the SessionStart hook did not, and the list of what to place in them. That stop IS the
  pass criterion — it proves the command and agent wiring works and that preflight fails loudly
  instead of improvising.
- [ ] **Jira path works.** With the Atlassian connector authorized, run
  `/research-ticket TICKET-1` (substitute any real ticket key from your Jira). It should
  fetch and report the ticket's details. Without the connector it stops immediately with the
  authorization instructions — also correct behavior, but not yet a pass for this item.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| A legitimate command or file write is denied by a safety hook | The git-write guard or secret/PHI guard matched a never-write pattern (rare false positives are by design — the hooks fail safe) | Reword the command (e.g. quote-in-a-string collisions) or replace the flagged value with an obviously fake placeholder (`SSN-PLACEHOLDER`, `member-0001`); if truly stuck, the developer can disable the plugin hook for one session |
| Plugin not offered when opening the project | `.claude/settings.json` missing from the repo, or the repo/marketplace is not trusted yet | Commit the settings block from section 2 (or install manually with the two `/plugin` commands) and accept the trust/install prompt when Claude Code shows it |
| `/research-ticket` stops immediately | Atlassian connector not authorized in this session | Authorize the Atlassian connector (claude.ai connector settings, or `/mcp` in an interactive session), then rerun the command — there is no fallback access path, by design |
| Figma links reported as inaccessible sources | The Figma connector is not authorized in this session | Authorize the Figma connector (claude.ai connector settings), then rerun — or export the referenced frames as PNG/PDF into `docs/input-specs/` (or attach them to the ticket); agents read image exports visually and never guess design intent from a URL |
| `/implement` refuses to run | The spec's Section 13 Approval Status is still DRAFT, or Section 12 (Open Questions) is not NONE | Review the spec, resolve every Section 12 question and set the section to NONE, then flip the Approval Status line yourself to exactly `APPROVED by {name} on {YYYY-MM-DD}` — no agent or command ever writes APPROVED |
| An agent reports PROJECT_BRIEF.md missing | `/onboard-project` has not been run on this project | Drop the SRS into `docs/input-specs/` and run `/onboard-project`; commit the generated brief and decision log |
| Everything is treated as PHI | The Compliance Profile in `PROJECT_BRIEF.md` is missing, incomplete, or unconfirmed — this is the fail-closed rule working as designed | Review Section 5 of the brief, resolve any "PHI (presumed — unconfirmed)" rows, and confirm the profile through the regeneration diff-and-approval flow |
| Plugin updates not arriving | Updates never land silently mid-sprint | Run `/plugin marketplace update` to pick up the new version |
