# Neovim Plugin Conventions

## Source
CONVENTIONS.md § Neovim Plugin Conventions

## Rules

- **Single entry point**: `lua/custom_ai/init.lua` returns module table
- **Configuration**: `setup(opts)` with `vim.tbl_deep_extend("force", defaults, opts)`
- **State**: Module-local tables (`state`, `config`) — no global variables
- **Async only**: Network via `vim.system()` with callbacks — NEVER `vim.fn.system()` blocking
- **Buffer-local keymaps**: Set inside chat buffer only, cleaned up on close
- **Floating windows**: `relative="editor"`, `style="minimal"`, `border="rounded"`
- **Read-only chat buffer**: `modifiable=false`, `readonly=true` except when writing
- **Error handling**: `vim.notify()` with appropriate log level (INFO/WARN/ERROR)
- **Temp files**: Use `vim.fn.tempname()` for large payloads (base64 images)
- **Model detection**: Query `/v1/models` endpoint, match filename to config keys

## Enforced By
- seed-conventions (generated CONVENTIONS.md)
- verify-work (static verification via luac -p)

## Last Updated
2026-01-10