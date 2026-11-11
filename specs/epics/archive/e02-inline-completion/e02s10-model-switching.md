# Story e02s10: Integration with existing model switching

**type:** feat
**risk:** P2
**context:** domain

## Context

Ensure completion uses the currently active model (state.current_model_key) set by switch_model() and refresh_model(). No separate completion_model config needed — user switches models via existing <leader>am keymap.

## Requirements

### ADDED: Use active model
Completion requests use state.current_model_key (set by switch_model, refresh_model)

### ADDED: Clear cached context on model switch
On model switch: clear any cached context, re-detect capabilities if needed

### ADDED: Model-specific completion config
Use model_config[model_key].completion for temperature, max_tokens, stop, etc.

### ADDED: No separate completion_model
Per scope decision: uses active model, no dedicated completion model config

## Implementation Steps

1. In request_completion, read state.current_model_key for model name → verify: `grep -q 'current_model_key' lua/custom_ai/completion.lua`

2. In switch_model() (init.lua), after server restart, clear any completion-specific cache → verify: `grep -q 'switch_model' lua/custom_ai/init.lua && grep -q 'completion' lua/custom_ai/init.lua`

3. Use model-specific completion config: local comp_cfg = config.model_config[state.current_model_key].completion or {} → verify: `grep -q 'model_config' lua/custom_ai/completion.lua && grep -q 'completion' lua/custom_ai/completion.lua`

4. Verify no completion_model config exists in init.lua → verify: `grep -qv 'completion_model' lua/custom_ai/init.lua`

5. Manual test: switch between coder/specialist/allrounder, verify completion style/quality changes → verify: `echo 'MANUAL: <leader>am switch models, trigger completion, observe differences'`

## Verification Script (Step-by-Step)

1. Start with coder model, trigger completion → observe style (concise, code-focused)
2. Switch to specialist model (<leader>am → specialist)
3. Trigger completion → observe style (more detailed, best practices)
4. Switch to allrounder model
5. Trigger completion → observe style (balanced)
6. Verify model_config.completion params applied per model (temperature, max_lines)

## Out of scope

- Dedicated completion model — explicitly out of scope per SCOPE_LATEST.yaml
- Model-specific context config — covered by model_config.completion

## Risks

- Model switch restarts server — completion requests during restart will fail (handled by e02s09)
- Different models may have different completion capabilities — config handles this