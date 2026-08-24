---
name: setup-repo
description: One-time bootstrap for a repo using the purandar-ai suite. Asks which role this repo plays (Backend / Frontend / Project Context), then merges the marketplace, plugin enablement, and permissions into .claude/settings.json and — for code repos pointing at a shared context repo — writes the .claude/ai-agent.json context pointer. Merge-safe, re-run safe; the developer reviews and commits; takes effect in a fresh session.
---

# /setup-repo

Bootstrap command, run once per repo (and again any time the repo's role or context location
changes). It configures THIS repo for the plugin suite by writing at most two files:
`.claude/settings.json` (merged, never clobbered) and `.claude/ai-agent.json` (the context
pointer, code repos in the shared-context topology only).

Rules that bind this command absolutely:

- It resolves NO context pointer — it runs before everything else and may be creating the
  pointer. It is the one command exempt from the shared-standards Context Root preflight.
- It NEVER touches `.claude/settings.local.json` (read it only to report), never creates or
  writes anything in the sibling context repo, never runs git — the developer reviews and
  commits, per the standing contract.
- Merge means merge: keys this command does not own are never modified, reordered away, or
  removed. A settings file it cannot parse is a hard stop, never an overwrite.

## Instructions

1. **Inventory.** Read `.claude/settings.json`, `.claude/settings.local.json` (report-only),
   and `.claude/ai-agent.json` if they exist. Report what is found: an existing `purandar-ai`
   marketplace entry yes/no; which purandar-ai plugins are currently enabled; an existing
   context pointer and its value. If `.claude/settings.json` exists but is not valid JSON,
   print exactly this and STOP:

   > /setup-repo cannot continue: .claude/settings.json is not valid JSON ({parser error}).
   > Fix or remove it, then rerun /setup-repo — this command never overwrites a file it
   > cannot parse.

2. **Ask the repo's role** (AskUserQuestion, one question): "Which repo is this?" Options:

   - **Backend** — Java/Spring Boot code repo (enables `ai-agent` + `ai-agent-backend`).
   - **Frontend** — React code repo (enables `ai-agent` + `ai-agent-frontend`).
   - **Project Context** — the shared docs repo holding input-specs, briefs, tickets, and the
     decision log (enables `ai-agent` only).

   If step 1 detected an existing configuration, name the detected current role in the question
   text as the suggested answer. A full-stack single repo is configured by running /setup-repo
   twice (Backend, then Frontend) — the merge is additive; say so in the closing when relevant.

3. **Ask where the project context lives** (code repos only — the Project Context repo IS the
   context, skip this): "Where does the project context (the docs tree) live?" Options:

   - **Sibling context repo (Recommended for multi-repo projects)** — writes the pointer;
     suggested value `../project-context/docs` (the developer may give another path via Other;
     it MUST be relative to this repo's root — absolute paths are machine-specific and
     rejected).
   - **This repo's own docs/ (single-repo mode)** — no pointer; everything behaves exactly as
     it did before 2.0.0. If a pointer file already exists, offer to delete it (with its
     current value shown) — otherwise it keeps winning.

4. **Compute the target fragment.** Exact shapes (backend shown; frontend swaps the plugin id;
   the Project Context repo gets only the marketplace entry and the core enablement — no
   permissions block, no pointer):

   ```json
   {
     "extraKnownMarketplaces": {
       "purandar-ai": {
         "source": { "source": "github", "repo": "AdityaP2024/purandar-agentic-ai" }
       }
     },
     "enabledPlugins": {
       "ai-agent@purandar-ai": true,
       "ai-agent-backend@purandar-ai": true
     }
   }
   ```

   In pointer mode, the fragment additionally carries the permissions block granting the
   session access to the sibling (the pointer value substituted for the example path):

   ```json
   {
     "permissions": {
       "additionalDirectories": ["../project-context/docs"]
     }
   }
   ```

   plus the pointer file content for `.claude/ai-agent.json`:

   ```json
   {
     "contextRoot": "../project-context/docs"
   }
   ```

   `additionalDirectories` makes the sibling readable without prompts, and writes into it (the
   brief, gap report, tickets, decisions) follow the developer's permission mode exactly like
   files in the repo itself: prompted per edit in the default mode, auto-approved in acceptEdits
   mode. File-edit approvals do not persist across sessions — a developer who wants promptless
   context-repo writes uses acceptEdits mode. Tell the developer this in the closing — it is
   expected behavior, not a misconfiguration. No permission `allow` rules are written: rule
   patterns cannot reach upward-relative paths, and none are needed.

5. **Merge — never clobber.** Deep-merge the fragment into the existing settings object
   (missing file = empty object):

   a. Objects merge recursively; keys this command does not own are never modified or removed.
   b. `extraKnownMarketplaces.purandar-ai` — replaced wholesale (idempotent; identical for
      1.x configs).
   c. `enabledPlugins` — ADD our ids set `true`; never remove or set `false` on anything
      already there. If a purandar-ai plugin id is enabled that this role does not need
      (e.g. the other stack), report it and ask before removing — the default is keep.
   d. `permissions.additionalDirectories` — set-union with any existing array, deduplicated.
   e. Format preservation: if the existing `enabledPlugins` is the ARRAY form
      (`["ai-agent@purandar-ai"]`), keep the array and append missing ids; otherwise (object
      or absent) use the object form shown above. Either form carries the literal
      `ai-agent@purandar-ai`, which the scaffold hook's enablement check greps for.
   f. **Show before → after**: the current file content and the proposed content (or a unified
      diff), plus the exact `.claude/ai-agent.json` to be written in pointer mode. If a pointer
      file exists with a DIFFERENT value, show that change explicitly too.
   g. **Confirm** (AskUserQuestion): Apply / Cancel. Only on Apply: write
      `.claude/settings.json` (2-space indent) and, in pointer mode, `.claude/ai-agent.json`.
      Cancel writes nothing and closes with a one-line nothing-was-written statement.

6. **Migration from 1.x is just a normal run.** A 1.x repo already carries the same marketplace
   entry and `"ai-agent@purandar-ai": true`; the merge is naturally additive. Name it when
   detected: "Existing 1.x configuration detected — keeping it and adding: {the stack plugin /
   permissions / pointer}." One extra guard in pointer mode: if this repo has local generated
   artifacts (`docs/output-specs/PROJECT_BRIEF.md`, `docs/decisions.md`, `docs/tickets/`), list
   them and warn:

   > These local artifacts will be ignored once the pointer is active — move them into
   > {contextRoot} yourself (the plugin never moves or commits files).

7. **Re-run behavior.** If the computed target equals the current state, print "Already
   configured as {role} — nothing to change." and offer (AskUserQuestion) to reconfigure the
   role or pointer, or exit. Any change goes through the same diff-and-confirm.

8. **Sibling existence check** (pointer mode). If the chosen contextRoot does not resolve to an
   existing directory right now, WARN but still write the configuration:

   > Note: {contextRoot} does not exist yet. Clone the project-context repo as a sibling before
   > running any pipeline command — they hard-stop on an unresolvable pointer.

9. **Closing** (after a successful write; substitute per repo type):

   > Setup complete. Review and commit .claude/settings.json{ and .claude/ai-agent.json} — the
   > developer commits, the plugin never does. Then START A FRESH SESSION: plugin enablement,
   > permissions, and hooks are read at session start.
   > {Project Context repo: the SessionStart hook will scaffold docs/input-specs/ and
   > docs/output-specs/ on that first fresh session — drop the SRS, MOMs, and design links in
   > and run /onboard-project. | Pointer mode: no docs directories are created in this repo —
   > they live in the context repo. Reads from it never prompt; writes into it follow your
   > permission mode (prompted per edit by default, automatic in acceptEdits mode).}
