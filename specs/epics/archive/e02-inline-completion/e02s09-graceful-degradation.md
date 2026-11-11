# Story e02s09: Graceful degradation (server unavailable, errors, empty response)

**type:** feat
**risk:** P1
**context:** domain

## Context

Handle all error scenarios gracefully: server unavailable, request timeout, parse errors, empty responses. Show error items in blink.cmp menu instead of failing silently. Auto-retry on next trigger.

## Requirements

### ADDED: Pre-flight server check
Quick HEAD/GET to /v1/models with short timeout before request

### ADDED: Server unavailable error item
blink.cmp item: label="AI: Server unavailable", kind=Text, detail="Start llama.cpp server"

### ADDED: Timeout handling
Request timeout (default 5s) → error item "AI: Request timeout"

### ADDED: Parse error handling
Invalid JSON, missing fields → error item "AI: Parse error"

### ADDED: Empty response handling
Model returns empty → error item "AI: Empty response"

### ADDED: Auto-retry
Next trigger attempts request again (no persistent error state)

## Implementation Steps

1. Add pre-flight check in request_completion: vim.system({ "curl", "-s", "-I", "-m", "1", models_url() }) → verify: `grep -q 'HEAD\\|v1/models' lua/custom_ai/completion.lua && grep -q 'timeout' lua/custom_ai/completion.lua`

2. On pre-flight failure: return error completion item { label = "AI: Server unavailable", kind = Text, detail = "Start llama.cpp server" } → verify: `grep -q 'Server unavailable' lua/custom_ai/completion.lua`

3. Add timeout to vim.system call (config.completion.timeout or 5000ms), handle timeout in callback → verify: `grep -q 'timeout' lua/custom_ai/completion.lua && grep -q 'Request timeout' lua/custom_ai/completion.lua`

4. Handle JSON parse errors: pcall(vim.json.decode), on failure return error item "AI: Parse error" → verify: `grep -q 'parse error\\|json.decode' lua/custom_ai/completion.lua && grep -q 'Parse error' lua/custom_ai/completion.lua`

5. Handle server error response: check data.error field, return error item with server message → verify: `grep -q 'data.error' lua/custom_ai/completion.lua`

6. Handle empty response: choices[0].text empty or missing → error item "AI: Empty response" → verify: `grep -q 'Empty response' lua/custom_ai/completion.lua`

7. Auto-retry: no persistent error flag, each trigger attempts fresh request → verify: `grep -q 'retry' lua/custom_ai/completion.lua`

8. Manual test: stop server, trigger completion, verify error item; restart server, verify recovery → verify: `echo 'MANUAL: pkill llama, trigger completion, verify error; restart server, verify works'`

## Verification Script (Step-by-Step)

1. Ensure llama.cpp server running, trigger completion → verify AI items appear
2. Stop server: `pkill -f "llama serve"`
3. Trigger completion → verify blink.cmp shows "AI: Server unavailable" item
4. Restart server: `cd ~ && ./llm-coder.sh`
5. Trigger completion → verify AI items restored (auto-retry works)
6. Test timeout: set timeout=1ms, trigger → verify "AI: Request timeout"
7. Test parse error: mock invalid JSON response (harder to test manually)

## Out of scope

- Persistent error state / circuit breaker — explicitly not needed
- Offline queue / retry later — explicitly not needed
- Server health monitoring — out of scope

## Risks

- Pre-flight adds latency — keep timeout very short (1s)
- blink.cmp error items must have correct kind for proper display
- Race condition: server dies between pre-flight and request — handle in request callback