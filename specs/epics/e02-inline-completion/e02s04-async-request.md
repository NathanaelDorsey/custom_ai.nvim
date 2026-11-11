# Story e02s04: Async completion request to llama.cpp with context injection

**type:** feat
**risk:** P0
**context:** domain

## Context

Non-blocking async request to llama.cpp completion endpoint with assembled context. Handles request queue, cancellation, timeouts, and error recovery. Integrates with context.lua for context gathering.

## Requirements

### ADDED: request_completion(prompt, callback) in completion.lua
Uses vim.system() async POST to /v1/completions (or /v1/chat/completions if completions endpoint unavailable).

### ADDED: Prompt template builder
System prompt + context sections + current file prefix + cursor context.

### ADDED: Request queue
Reuse or adapt existing queue mechanism (state.queue) to prevent overlapping requests.

### ADDED: Cancellation
If new trigger before previous completes, cancel previous request (vim.system kill).

### ADDED: Timeout handling
Configurable timeout (default 5s), graceful timeout handling.

### ADDED: Error handling
Network error, server error, parse error → return error completion item.

### ADDED: Context integration
Call context.gather_context(), inject into prompt, send request.

## Implementation Steps

1. Add request_completion(context, callback) to completion.lua using vim.system() with curl POST to /v1/completions → verify: `grep -q 'request_completion' lua/custom_ai/completion.lua && grep -q 'vim.system' lua/custom_ai/completion.lua && grep -q '/v1/completions' lua/custom_ai/completion.lua`

2. Build prompt template: system instruction + context (imports, types, related_fns, tests) + file prefix (10 lines before cursor) + cursor line → verify: `grep -q 'prompt' lua/custom_ai/completion.lua && grep -q 'context' lua/custom_ai/completion.lua`

3. Add completion-specific queue or reuse state.queue: track in-flight request, queue subsequent triggers → verify: `grep -q 'queue' lua/custom_ai/completion.lua`

4. Implement cancellation: store vim.system handle, on new trigger call handle:kill() if previous in-flight → verify: `grep -q 'kill\\|cancel' lua/custom_ai/completion.lua`

5. Add timeout config (default 5000ms) to vim.system call, handle timeout in callback → verify: `grep -q 'timeout' lua/custom_ai/completion.lua`

6. Error handling: check result.code, result.stderr, JSON parse, server error field → return error completion item → verify: `grep -q 'error' lua/custom_ai/completion.lua && grep -q 'result.code' lua/custom_ai/completion.lua`

7. Integrate context.lua: require("custom_ai.context").gather_context(), inject into prompt template → verify: `grep -q 'require.*context' lua/custom_ai/completion.lua`

8. Use model-specific params from model_config[model_key].completion (temperature, max_tokens, stop) → verify: `grep -q 'model_config' lua/custom_ai/completion.lua && grep -q 'temperature' lua/custom_ai/completion.lua`

9. Manual test: verify async (UI doesn't freeze), queue works, cancellation works, errors handled → verify: `echo 'MANUAL: Trigger multiple rapid completions, verify no UI freeze, check queue behavior'`

## Verification Script (Step-by-Step)

1. Open Neovim with llama.cpp server running
2. Trigger completion rapidly 3-4 times (<C-space> quickly)
3. Verify UI remains responsive (no freeze)
4. Verify only last request completes (cancellation works)
5. Stop server, trigger completion, verify error item in blink.cmp menu
6. Restart server, trigger completion, verify recovery

## Out of scope

- Context gathering implementation — story e02s03
- Prompt template specifics for single/multi-line — stories e02s05/e02s06
- Response parsing — stories e02s05/e02s06

## Risks

- llama.cpp may not support /v1/completions — fallback to /v1/chat/completions with single user message
- Queue/cancellation race conditions — test thoroughly with rapid triggers
- Large context may exceed model context window — truncate in context.lua (e02s03)
- Server streaming vs non-streaming — use non-streaming for simplicity (blocking)