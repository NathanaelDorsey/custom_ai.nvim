# Project

## Source
CLAUDE.md § bigpowers:project

## Description
Neovim plugin for local llama.cpp AI integration — connects to a llama-server instance running on your machine.

## Stack
Lua 5.1/5.4, Neovim 0.10+, llama.cpp server (OpenAI-compatible API on port 9931)

## Architecture
Single-file Lua plugin (`lua/custom_ai/init.lua`) with:
- Config-driven model management
- Floating chat window
- Message queue
- Server lifecycle (start/kill/switch)
- Vision support (image_url content parts)
- Code editing (full file + selection)
- Test runner with AI analysis

## Commands
| Action | Command |
|--------|---------|
| Run | Manual test in Neovim (`:lua require("custom_ai").chat()`) |
| Test | Manual validation in Neovim |
| Build | N/A — Lua plugin, no build step |
| Lint | N/A — Lua plugin, no lint step |
| Preflight | Manual test in Neovim |
| CI | `gh pr checks` (when a PR is open) |

## Enforced By
- seed-conventions (generated CLAUDE.md)

## Last Updated
2026-01-10