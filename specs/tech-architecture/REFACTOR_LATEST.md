# REFACTOR_LATEST.md — Refactor Plan for custom_ai.nvim

## Current State
Single-file `lua/custom_ai/init.lua` (~600 lines) working well. No immediate refactor needed.

## Potential Future Refactors (If Plugin Grows)

### 1. Split into Multiple Files
```
lua/custom_ai/
├── init.lua           -- public API, setup, re-exports
├── config.lua         -- defaults, validation, merge
├── state.lua          -- state management
├── server.lua         -- lifecycle: start, kill, detect, switch
├── chat.lua           -- chat window, buffer, keymaps
├── api.lua            -- send_prompt, queue, HTTP
├── features/
│   ├── ask.lua        -- ask_file, ask
│   ├── edit.lua       -- edit_code, edit_selection
│   ├── test.lua       -- run_tests, truncate_test_output
│   └── vision.lua     -- image_to_data_url
└── util.lua           -- write_to_buf, split_lines, temp files
```

**Trigger**: File exceeds 800 lines or distinct features need independent testing.

### 2. Extract Server Management
- Move `start_server`, `kill_server`, `detect_running_model` to `server.lua`
- Allows mocking in tests (if test framework added)

### 3. Event-Based Architecture
- Replace direct callback chaining with event emitter
- Enables: logging, metrics, multiple UI consumers

### 4. Configuration Schema Validation
- Add `vim.validate()` or custom schema in `config.lua`
- Fail fast on invalid user config

## Refactor Principles
- **One at a time**: Single PR per split
- **Preserve API**: `require("custom_ai").chat()` unchanged
- **No behavior change**: Refactor only, no new features
- **Manual verification**: Run all TEST_PLAN scenarios after each