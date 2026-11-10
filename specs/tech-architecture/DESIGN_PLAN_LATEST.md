# DESIGN_PLAN_LATEST.md — Design Plan for custom_ai.nvim

## Current Design (Implemented)

### Module Structure
```
lua/custom_ai/init.lua
└── M = {} (returned module)
    ├── setup(opts)              -- configuration
    ├── chat()                   -- open/focus chat window
    ├── ask()                    -- ask about current file
    ├── ask_file()               -- alias for ask
    ├── edit_code()              -- edit entire file
    ├── edit_selection()         -- edit visual selection
    ├── run_tests()              -- run tests + AI analysis
    ├── switch_model()           -- UI model selector + switch
    ├── refresh_model()          -- re-detect running model
    ├── check_server_on_startup()-- auto-detect on load
    ├── show_scripts()           -- display startup scripts
    ├── new_chat()               -- clear history
    ├── send_prompt()            -- core async HTTP + queue
    ├── detect_running_model()   -- GET /v1/models + fuzzy match
    ├── start_server(key)        -- kill + start script + verify
    ├── kill_server()            -- pkill + state cleanup
    └── Helpers (image_to_data_url, write_to_buf, split_lines, truncate_test_output)
```

### Data Flow

```
User Action (keymap)
    ↓
Handler (e.g., edit_code)
    ↓
Build Prompt (file content + instruction)
    ↓
send_prompt(prompt, callback, history)
    ↓
Queue if sending → else send immediately
    ↓
vim.system(curl) → callback(response)
    ↓
Write to chat buffer via write_to_buf()
    ↓
Process queue (recursive)
```

### UI Design
- **Chat window**: Floating, 40% width, 80% height, centered-right, rounded border
- **Response window**: Bottom bar, 30% height, full width, for test results
- **Keymaps**: Buffer-local, `<leader>a` prefix (except toggle `<leader>.`)
- **Read-only**: Chat buffer non-editable, responses appended programmatically

### Configuration Design
- Single `setup(opts)` call, deep-merged with defaults
- All user-facing behavior configurable: models, scripts, keymaps, test commands
- Per-model generation params (`model_config`) with global fallback

## Future Design Considerations

### Streaming Support (Deferred)
- Would require `stream: true` + SSE parsing in `vim.system` callback
- Current non-streaming simpler, sufficient for local low-latency

### Multi-Server Support (Out of Scope)
- Single port design matches single-GPU constraint
- User manages multiple ports via shell if needed

### Telescope Integration (Deferred)
- Could add model picker via telescope.nvim
- Current `vim.ui.select` sufficient, zero deps

### Session Persistence (Deferred)
- Save/load `state.messages` to disk
- Current in-memory only, cleared on Neovim restart