# TEST_PLAN_LATEST.md — Test Plan for custom_ai.nvim

## Test Strategy

**No automated test framework** — Neovim Lua plugins typically validate manually.
All testing is **manual integration testing** in a live Neovim session.

## Test Scenarios

### 1. Server Detection & Startup
- [ ] Fresh Neovim, no server running → shows startup scripts notification
- [ ] Server running (allrounder) → auto-detects model, shows in chat header
- [ ] Server running (unknown model) → shows "no model running", allows manual switch
- [ ] Server on wrong port → graceful error, shows scripts

### 2. Chat Window
- [ ] `<leader>.` opens floating chat at correct position/size
- [ ] Chat buffer is read-only, modifiable=false
- [ ] Toggle `<leader>.` hides/shows window correctly
- [ ] New chat `<leader>an` clears history, creates fresh buffer
- [ ] Multiple opens reuses existing buffer/window

### 3. Message Sending (Text)
- [ ] `<leader>as` prompts for input, sends, shows "AI thinking..."
- [ ] Response appears in chat buffer with "AI: " prefix
- [ ] Conversation history maintained across messages
- [ ] Queue: rapid `<leader>as` sends process sequentially

### 4. Vision (Image + Text)
- [ ] `<leader>av` prompts for text + image path
- [ ] Valid image → base64 encoded, sent as image_url content part
- [ ] Invalid path → warning, falls back to text-only
- [ ] Response appears normally

### 5. Model Switching
- [ ] `:lua require("custom_ai").switch_model()` shows selector
- [ ] Select different model → kills old server, starts new script
- [ ] Health check passes → "Server ready" notification
- [ ] Chat header updates to new model name
- [ ] Invalid selection → warning, no change

### 6. File-Aware Ask
- [ ] `<leader>af` in a file → prompts question
- [ ] Sends file path + content + question to AI
- [ ] Response appears in chat

### 7. Code Editing (Full File)
- [ ] `<leader>ae` in a file → prompts instruction
- [ ] Sends full file content + instruction
- [ ] Replaces buffer content with AI response (strips markdown fences)
- [ ] Buffer modifiable temporarily, then readonly restored

### 8. Selection Editing
- [ ] Visual select lines → `<leader>ah` → prompts instruction
- [ ] Sends full file context + selected text + instruction
- [ ] Replaces only selected lines with AI response
- [ ] Non-selected lines unchanged

### 9. Test Analysis
- [ ] `<leader>at` → shows test command selector
- [ ] Select pytest/python/bash/etc. → runs command on current file
- [ ] Captures stdout/stderr, truncates to key failures
- [ ] Sends truncated output to AI for analysis
- [ ] AI response appears in chat

### 10. Edge Cases
- [ ] Server dies mid-request → error notification, queue pauses
- [ ] Large image (>10MB) → temp file handling works
- [ ] Empty file edit → handles gracefully
- [ ] No visual selection for `<leader>ah` → warning
- [ ] Config validation: invalid default_model → falls back to first key

## Regression Checklist (per release)

Run all scenarios above. Any failure = block release.

## Performance Baselines

- Chat open: < 100ms
- Model switch: < 5s (server restart dominates)
- First message (cold server): < 3s (health check defer)
- Subsequent messages: network RTT only