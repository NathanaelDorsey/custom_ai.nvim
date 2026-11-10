# custom_ai.nvim — AI Agents

Read CONVENTIONS.md before any GitHub or git operation.

<!-- BEGIN bigpowers:project -->
## Project
Neovim plugin for local llama.cpp AI integration — connects to a llama-server instance running on your machine.
Stack: Lua 5.1/5.4, Neovim 0.10+, llama.cpp server (OpenAI-compatible API on port 9931)

## Commands
| Action | Command |
|--------|---------|
| Run    | Manual test in Neovim (`:lua require("custom_ai").chat()`) |
| Test   | Manual validation in Neovim |
| Build  | N/A — Lua plugin, no build step |
| Lint   | N/A — Lua plugin, no lint step |
| Preflight | Manual test in Neovim |
| CI     | `gh pr checks` (when a PR is open) |

## Architecture
Single-file Lua plugin (lua/custom_ai/init.lua) with config-driven model management, floating chat window, message queue, server lifecycle (start/kill/switch), vision support (image_url content parts), code editing (full file + selection), test runner with AI analysis

## Conventions
- Single init.lua entry point with setup(opts) accepting deep-merged config
- Buffer-local keymaps inside chat window only
- Async HTTP via vim.system (never block Neovim UI)
- Module-local state tables for chat, queue, server PID, detected model
- Config-driven: models, scripts, keymaps, test commands all user-configurable
- Model auto-detection via GET /v1/models endpoint with filename matching

## Never
- Never dismiss reproducible gate failures as pre-existing or out of scope
- Never proceed on red Preflight or red CI — invoke quick-fix or fix-bug first
- Never block Neovim UI (all network async via vim.system)
- Never hardcode server URLs outside config
- Never commit example shell scripts
- Never assume model availability — always detect or fallback

## Agent Rules
- **Workflow Mandate:** You MUST use the bigpowers skills (e.g. `plan-work`, `develop-tdd`, `orchestrate-project`) to perform tasks. DO NOT write code directly in response to a user prompt like "build this feature".
- **Always Green:** Preflight and CI must be green before forward work. Reproducible gate failures require **fix-or-log** (quick-fix → fix-bug) per CONVENTIONS § Discovered Defects.
- Read specs/ before writing code.
- All planning and specifications MUST be written to `specs/` (`product/SCOPE_LATEST.yaml`, `release-plan.yaml`, `epics/`) before any code is generated.
- Write the minimum code that solves the stated problem. Nothing extra.
- Run tests after every change. Show evidence before declaring done.
- One clarifying question beats a wrong assumption baked into 200 lines.
<!-- END bigpowers:project -->

<!-- BEGIN bigpowers:context-routing -->
## Context Routing
No sub-AGENTS.md files — single project scope
<!-- END bigpowers:context-routing -->

<!-- BEGIN bigpowers:learned-preferences -->
## Learned User Preferences + Workspace Facts
- Prefers async/non-blocking Neovim patterns
- Uses lazy.nvim for plugin management
- Runs llama.cpp server locally on port 9931
- Switches between multiple specialized models (allrounder, coder, specialist, efficient, vision)
<!-- END bigpowers:learned-preferences -->

<!-- BEGIN bigpowers:tooling -->
## Tooling
No project-local tooling installed
<!-- END bigpowers:tooling -->