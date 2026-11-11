# Story e02s01: Tracer Bullet — Manual trigger → blink.cmp source → single-line completion

**type:** feat
**risk:** P0
**context:** domain

## Context

Thin vertical slice proving end-to-end plumbing: user presses `<C-space>` in insert mode → blink.cmp menu opens → custom_ai source returns one AI completion (single-line, minimal context). This validates the blink.cmp integration, async request flow, and response parsing before building context gathering, multi-line, config, etc.

## Requirements

### ADDED: Manual trigger keymap in insert mode
User presses `<C-space>` in insert mode to request AI completion.

### ADDED: blink.cmp source registration
custom_ai registers as a blink.cmp source named "custom_ai" with proper completion item format.

### ADDED: Async request to llama.cpp /v1/completions
Non-blocking vim.system() POST to /v1/completions with a minimal prompt, returning one completion item.

### ADDED: Single-line completion parsing
Parse llama.cpp response, extract text before first newline, return as blink.cmp Snippet item.

## Implementation Steps

1. Create `lua/custom_ai/completion.lua` module with blink.cmp source boilerplate (name, get_completions function) → verify: `test -f lua/custom_ai/completion.lua && grep -q 'get_completions' lua/custom_ai/completion.lua`

2. Add blink.cmp source registration in `custom_ai.setup()` — merge user's blink.cmp sources with custom_ai source, respecting `config.completion.enabled` → verify: `grep -q 'blink.cmp' lua/custom_ai/init.lua && grep -q 'completion' lua/custom_ai/init.lua`

3. Add insert-mode keymap `<C-space>` (configurable via `config.keymaps.completion_trigger`) that calls blink.cmp's manual trigger API or feeds keys → verify: `grep -q 'completion_trigger' lua/custom_ai/init.lua && grep -q '<C-space>' lua/custom_ai/init.lua`

4. Implement `request_completion(context, callback)` in completion.lua using `vim.system()` POST to `/v1/completions` with minimal prompt (current line + 5 lines before) → verify: `grep -q 'request_completion' lua/custom_ai/completion.lua && grep -q 'vim.system' lua/custom_ai/completion.lua`

5. Build minimal prompt template: system instruction + file prefix (5 lines before cursor) + cursor line → verify: `grep -q 'prompt' lua/custom_ai/completion.lua`

6. Parse llama.cpp `/v1/completions` response: extract `choices[0].text`, take text before first `\n`, trim → verify: `grep -q 'choices\[0\]\.text' lua/custom_ai/completion.lua && grep -q '\\n' lua/custom_ai/completion.lua`

7. Return blink.cmp completion item: `{ label = completion_text, kind = require("blink.cmp.types").CompletionItemKind.Snippet, detail = "AI (1-line)", insertText = completion_text }` → verify: `grep -q 'CompletionItemKind' lua/custom_ai/completion.lua && grep -q 'insertText' lua/custom_ai/completion.lua`

8. Add completion config defaults to `init.lua`: `completion = { enabled = true, keymap = "<C-space>", trigger_chars = {} }` and `model_config[*].completion = { max_lines = 1, ... }` → verify: `grep -q 'completion = {' lua/custom_ai/init.lua && grep -q 'max_lines' lua/custom_ai/init.lua`

9. Manual E2E test: start llama.cpp server (coder model), open Neovim, type `local function test()`, press `<C-space>`, verify blink.cmp menu shows AI completion item → verify: `echo 'MANUAL: Start server, open nvim, type "local function test()", press <C-space>, verify AI item in blink.cmp menu'`

## Verification Script (Step-by-Step)

1. Start llama.cpp server with coder model: `cd ~ && ./llm-coder.sh`
2. Wait for server ready (check `curl -s http://127.0.0.1:9931/v1/models`)
3. Open Neovim with a Lua file: `nvim test.lua`
4. Enter insert mode, type: `local function test()`
5. Press `<C-space>` (or configured keymap)
6. Observe blink.cmp menu opens with "custom_ai" source indicator
7. Verify at least one AI completion item appears with detail "AI (1-line)"
8. Accept completion with `<CR>` or `<Tab>`, verify text inserted

## Out of scope

- Project context gathering (LSP/treesitter) — story e02s03
- Multi-line completions — story e02s06
- Configuration granularity — story e02s07
- Toggle on/off — story e02s08
- Graceful degradation — story e02s09

## Risks

- blink.cmp API changes — mitigate by checking blink.cmp version and using stable APIs
- llama.cpp `/v1/completions` vs `/v1/chat/completions` — verify endpoint compatibility with running server
- Insert mode keymap conflicts — ensure `<C-space>` doesn't override critical builtins (it's commonly free)