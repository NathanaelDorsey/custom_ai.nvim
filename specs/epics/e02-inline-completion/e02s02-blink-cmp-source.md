# Story e02s02: blink.cmp source registration and config integration

**type:** feat
**risk:** P1
**context:** domain

## Context

Properly register custom_ai as a blink.cmp source with correct completion item kinds, labels, and configuration integration. Ensures the source appears in blink.cmp's source list, respects enable/disable, and integrates with custom_ai's config system (global_keymaps, model_config).

## Requirements

### ADDED: blink.cmp source spec definition
custom_ai defines a blink.cmp source with name="custom_ai", module="custom_ai.completion", and proper opts.

### ADDED: Config integration
Completion settings integrated into custom_ai defaults: `completion.enabled`, `completion.keymap`, `completion.trigger_chars`.

### ADDED: global_keymaps respect
Completion keymap respects `config.global_keymaps` setting (global vs buffer-local).

### ADDED: blink.cmp config merge
custom_ai.setup() merges custom_ai source into user's existing blink.cmp sources without overwriting.

## Implementation Steps

1. Define blink.cmp source spec in completion.lua: `return { name = "custom_ai", module = "custom_ai.completion", opts = { enabled = function() return require("custom_ai").config.completion.enabled end } }` → verify: `grep -q "name = 'custom_ai'" lua/custom_ai/completion.lua && grep -q 'module = "custom_ai.completion'" lua/custom_ai/completion.lua`

2. Add completion config block to defaults in init.lua: `completion = { enabled = true, keymap = "<C-space>", trigger_chars = {}, max_items = 5 }` → verify: `grep -q 'completion = {' lua/custom_ai/init.lua && grep -q 'trigger_chars' lua/custom_ai/init.lua && grep -q 'max_items' lua/custom_ai/init.lua`

3. In setup(), after deep_extend, register custom_ai source with blink.cmp by modifying user's blink.cmp config (if blink.cmp is loaded) or defer until blink.cmp loads → verify: `grep -q 'blink.cmp' lua/custom_ai/init.lua && grep -q 'sources' lua/custom_ai/init.lua`

4. Respect global_keymaps for completion keymap: if global_keymaps=true, set global insert-mode keymap; if false, set buffer-local in relevant filetypes → verify: `grep -q 'global_keymaps' lua/custom_ai/completion.lua && grep -q 'buffer' lua/custom_ai/completion.lua`

5. Verify: open Neovim, run `:BlinkCmpSources` or check completion menu source indicator, verify "custom_ai" listed → verify: `echo 'MANUAL: Open nvim, :BlinkCmpSources, verify custom_ai listed'`

## Verification Script (Step-by-Step)

1. Open Neovim with custom_ai loaded
2. Run `:BlinkCmpSources` (or `:lua print(vim.inspect(require("blink.cmp.config").sources))`)
3. Verify "custom_ai" appears in sources list
4. Check that `config.completion.enabled = false` removes it from sources
5. Verify keymap works in insert mode (global or buffer-local per global_keymaps)

## Out of scope

- Context gathering — story e02s03
- Async request implementation — story e02s04
- Completion item parsing — story e02s01

## Risks

- blink.cmp lazy-loading — source registration must handle blink.cmp not yet loaded
- User may have custom blink.cmp config — must merge, not replace
- blink.cmp API stability — use documented public APIs only