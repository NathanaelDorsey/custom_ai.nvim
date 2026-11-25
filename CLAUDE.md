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

### Startup Scripts (llama/scripts/)
Optimized llama.cpp server launchers with:
- KV cache quantization: `-ctk q4_0 -ctv q4_0` (~40% VRAM reduction for long contexts)
- Increased batch size: `-b 4096` (better GPU throughput)
- YaRN scaling for Qwen3-8B: 32K→65K context extension
- Model-specific GPU layers & context sizes tuned for 8GB VRAM

| Model | Script | Context | Cache | VRAM |
|-------|--------|---------|-------|------|
| specialist | llm-QWEN2.5-CODER-7B-specialist-32k.sh | 32K native | q4_0 | ~6.8 GB |
| coder | llm-QWEN3-8B-coder-reasoning-tools-24k.sh | 32K native | q4_0 | ~5.2 GB |
| coder_yarn | llm-QWEN3-8B-coder-reasoning-tools-yarn-65k.sh | 65K YaRN | q4_0 | ~6.5 GB |
| allrounder | llm-NEMOTRON-allrounder-reasoning-tools-65k.sh | 65K native | q4_0 | ~5.8 GB |
| efficient | llm-QWEN3.5-4B-efficient-reasoning-tools-16k.sh | 16K native | q4_0 | ~5.0 GB |
| vision | llm-llava-next-8b-vision.sh | 4K (mmproj) | q4_0 | ~6.5 GB |
| inkling_iq4 | llm-Inkling2-Mini-IQ4_XS.sh | 4K | q4_0 | ~7.2 GB |

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
- Switches between multiple specialized models (allrounder, coder, specialist, efficient, vision, inkling_iq4, coder_yarn)
- All models optimized with KV q4_0 cache quantization, YaRN 65K context extension, batch 4096
- Container-aware: auto-starts podman container if stopped
<!-- END bigpowers:learned-preferences -->

<!-- BEGIN bigpowers:tooling -->
## Tooling
No project-local tooling installed
<!-- END bigpowers:tooling -->