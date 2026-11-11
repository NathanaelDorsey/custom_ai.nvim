# Story e02s08: Global on/off toggle (command + keymap)

**type:** feat
**risk:** P2
**context:** domain

## Context

Add global toggle to enable/disable the custom_ai blink.cmp source at runtime. Provides command `:AICompletionToggle` and keymap `<leader>ac` (configurable).

## Requirements

### ADDED: State flag
state.completion_enabled = true (default)

### ADDED: Toggle function
M.toggle_completion() — flips state, re-registers/unregisters blink.cmp source dynamically

### ADDED: User command
:AICompletionToggle — calls toggle_completion()

### ADDED: Keymap
<leader>ac (configurable via config.keymaps.toggle_completion)

### ADDED: Notification
Show "AI Completion: enabled/disabled" on toggle

## Implementation Steps

1. Add state.completion_enabled = true to module state in init.lua → verify: `grep -q 'completion_enabled' lua/custom_ai/init.lua`

2. Implement M.toggle_completion() in init.lua: flip state, if blink.cmp loaded, call require("blink.cmp.config").setup() with updated sources or use blink.cmp's enable/disable API → verify: `grep -q 'toggle_completion' lua/custom_ai/init.lua && grep -q 'blink.cmp' lua/custom_ai/init.lua`

3. Add :AICompletionToggle user command in setup() → verify: `grep -q 'AICompletionToggle' lua/custom_ai/init.lua`

4. Add keymap <leader>ac in setup_global_keymaps() (configurable via config.keymaps.toggle_completion) → verify: `grep -q 'toggle_completion' lua/custom_ai/init.lua && grep -q '<leader>ac' lua/custom_ai/init.lua`

5. Show notification on toggle: vim.notify("AI Completion: " .. (state.completion_enabled and "enabled" or "disabled"), vim.log.levels.INFO) → verify: `grep -q 'notify' lua/custom_ai/init.lua && grep -q 'Completion' lua/custom_ai/init.lua`

6. Manual test: toggle off, verify blink.cmp menu shows no AI items; toggle on, verify restored → verify: `echo 'MANUAL: Press <leader>ac, trigger completion, verify disabled; press again, verify enabled'`

## Verification Script (Step-by-Step)

1. Open Neovim, verify AI completion works (<C-space> shows AI items)
2. Press <leader>ac (or run :AICompletionToggle)
3. Verify notification "AI Completion: disabled"
4. Trigger completion (<C-space>) → verify no AI items in blink.cmp menu
5. Press <leader>ac again
6. Verify notification "AI Completion: enabled"
7. Trigger completion → verify AI items restored

## Out of scope

- Per-buffer/project toggle granularity — explicitly deferred
- Auto-disable in comments/strings — explicitly deferred

## Risks

- blink.cmp source enable/disable API may not exist — may need to re-register sources
- Toggle must be instant — no server restart needed