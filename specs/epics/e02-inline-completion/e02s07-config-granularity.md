# Story e02s07: Completion granularity configuration (per-model / per-filetype)

**type:** feat
**risk:** P2
**context:** domain

## Context

Extend configuration system to support per-model and per-filetype completion settings. Allows users to customize completion behavior (max_lines, temperature, stop sequences, prompt template) for different models and filetypes.

## Requirements

### ADDED: model_config.completion table
Per-model config: max_lines, temperature, top_p, max_tokens, stop_sequences, prompt_template

### ADDED: Filetype-specific overrides
config.completion.filetypes = { lua = { max_lines = 10 }, python = { max_lines = 5, temperature = 0.1 }, ... }

### ADDED: Config resolution
Deep merge: model_config → filetype override → global default

### ADDED: Apply resolved config
Select prompt template, stop sequences, token limits per request

### ADDED: Documentation
README.md updated with completion config section

## Implementation Steps

1. Extend model_config defaults in init.lua with completion table for each model: { max_lines = 5, temperature = 0.3, top_p = 0.9, max_tokens = 256, stop_sequences = {}, prompt_template = nil } → verify: `grep -q 'completion = {' lua/custom_ai/init.lua && grep -q 'prompt_template' lua/custom_ai/init.lua && grep -q 'stop_sequences' lua/custom_ai/init.lua`

2. Add filetype overrides to config: `completion = { filetypes = { lua = { max_lines = 10 }, python = { max_lines = 5, temperature = 0.1 }, go = { max_lines = 8 } } }` → verify: `grep -q 'filetypes' lua/custom_ai/init.lua`

3. Implement config resolution in completion.lua: resolve_completion_config(model_key, filetype) → deep merge model_config → filetype override → global default → verify: `grep -q 'vim.tbl_deep_extend' lua/custom_ai/completion.lua && grep -q 'resolve.*config' lua/custom_ai/completion.lua`

4. Apply resolved config to request: select prompt_template, stop_sequences, max_tokens, temperature → verify: `grep -q 'stop_sequences\\|prompt_template\\|max_tokens' lua/custom_ai/completion.lua`

5. Document config options in README.md (completion section) → verify: `test -f README.md && grep -q 'completion' README.md`

6. Manual test: switch models, verify completion behavior changes; test filetype overrides → verify: `echo 'MANUAL: Switch models via <leader>am, verify completion params change; open different filetypes'`

## Verification Script (Step-by-Step)

1. Set model_config.coder.completion.max_lines = 1, model_config.specialist.completion.max_lines = 10
2. Switch to coder model (<leader>am), trigger completion → verify single-line
3. Switch to specialist model, trigger completion → verify multi-line
4. Set config.completion.filetypes.lua.max_lines = 3, config.completion.filetypes.python.max_lines = 15
5. Open Lua file, trigger → verify ~3 lines max
6. Open Python file, trigger → verify ~15 lines max

## Out of scope

- Per-buffer/project toggle — story e02s08 (global only)
- Context config — story e02s03

## Risks

- Deep merge order must be correct: global → model → filetype
- prompt_template as string vs function — support both
- Filetype detection: use vim.bo.filetype