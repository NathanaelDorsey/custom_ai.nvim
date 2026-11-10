# Code Style

## Source
CONVENTIONS.md § Code Style

## Rules

- Indent: 2 spaces (Lua standard)
- Functions: `local function name()` for private, `function M.name()` for public
- Tables: trailing commas in multi-line
- Strings: double quotes preferred
- Comments: `--` for inline, `--[[ ]]` for blocks
- No external dependencies beyond Neovim stdlib + `curl` in PATH

## Enforced By
- verify-work (luac -p syntax check)

## Last Updated
2026-01-10