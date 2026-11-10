# SECURITY_PLAN_LATEST.md — Security Plan for custom_ai.nvim

## Threat Model

**Assets:**
- User's local code (sent to llama.cpp server for context)
- Server startup scripts (executed via bash)
- Image files (read and base64-encoded for vision)

**Trust Boundaries:**
- Neovim process (trusted)
- llama.cpp server (trusted, local, user-controlled)
- Shell scripts (user-provided, executed with user privileges)
- Network: localhost:9931 only

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Command injection via file paths | Low | High | No shell interpolation in file reads; `vim.fn.expand()` only |
| Path traversal in image upload | Low | Medium | `io.open()` with explicit path; no user-controlled path concatenation |
| Server script execution | Medium | High | User provides scripts; plugin only executes configured paths |
| Large payload DoS (base64 images) | Low | Medium | Temp file streaming; no memory buffering beyond Neovim limits |
| Information leakage via logs | Low | Low | `vim.notify()` only; no persistent logging of code/content |

## Secure Coding Practices

- **Never** use `vim.fn.system()` with user input — use `vim.system({cmd, args...})`
- **Never** interpolate paths into shell commands — pass as argv array
- **Never** write user code to disk except temp files for curl payload
- **Always** use `vim.fn.tempname()` for temp files (unpredictable names)
- **Always** clean up temp files in all code paths (success + error)
- **Never** log conversation content or code to notify

## Data Handling

- Conversation history: in-memory only (`state.messages`), cleared on new chat
- File content: read via `vim.api.nvim_buf_get_lines()`, sent in request, not stored
- Images: read → base64 → temp file → curl → deleted
- Server scripts: executed as-is, no modification or validation

## Network

- All requests to `http://127.0.0.1:9931` (configurable host/port)
- No external network calls
- No authentication headers (local server)
- Timeout: `curl -m 2` for detection, implicit for chat (no streaming)

## Supply Chain

- No external Lua dependencies
- No package registry
- Distribution: GitHub source only
- User audits `init.lua` before install