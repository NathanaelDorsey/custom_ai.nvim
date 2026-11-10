# tech-stack.md — Technology Stack for custom_ai.nvim (Derived from Code)

## Runtime
- **Neovim**: 0.10+ (requires `vim.system`, `vim.json`, `vim.base64`, `vim.ui.select`, `vim.fn.tempname`)
- **Lua**: 5.1 (LuaJIT 2.1) — Neovim's embedded runtime
- **No luarocks / external Lua deps** — pure stdlib + Neovim API

## External Dependencies (Runtime, via shell)
| Tool | Purpose | Called Via |
|------|---------|------------|
| `curl` | HTTP client for llama.cpp API | `vim.system({ "curl", ... })` |
| `bash` | Execute server startup scripts | `vim.fn.jobstart({ "bash", "-c", ... })` |
| `pkill` / `kill` | Server process termination | `vim.fn.jobstart({ "pkill", ... })` |
| `pgrep` | Server PID detection | `vim.fn.jobstart({ "bash", "-c", "pgrep ..." })` |

## Architecture Pattern

### Module Structure
Single-file plugin: `lua/custom_ai/init.lua` (~570 lines)
- **Module pattern**: Returns table `M` with public API
- **Configuration**: `setup(opts)` with `vim.tbl_deep_extend("force", defaults, opts)`
- **State**: Two module-scoped tables — `config` (merged settings) and `state` (runtime)

### State Model
```lua
config = {}  -- Deep-merged user config + defaults
state = {
  buf = nil,              -- Chat buffer handle
  win = nil,              -- Chat window handle
  messages = {},          -- Conversation history (OpenAI message format)
  queue = {},             -- Pending requests {prompt, callback, history, tmp_file}
  sending = false,        -- Request in-flight flag
  detected_model = nil,   -- Auto-detected model key from /v1/models
  server_pid = nil,       -- llama-server process ID
  current_model_key = nil -- Active config key (e.g., "allrounder")
}
```

### Data Flow
```
User Action (buffer-local keymap)
    ↓
Feature Function (ask_file, edit_code, edit_selection, run_tests)
    ↓
Build Prompt (file content + instruction OR test output + instruction)
    ↓
send_prompt(prompt, callback, history)
    ↓
[Queue if sending] → else → vim.system(curl POST /v1/chat/completions)
    ↓
Callback → write_to_buf(chat_buffer) → Process queue (recursive)
```

## Configuration Schema (Observed)

```lua
{
  server = { host = "127.0.0.1", port = 9931 },
  models = { key = "Display Name" },                    -- 5 default keys
  model_config = { key = { temperature, top_p, max_tokens } },  -- Per-model gen params
  default_model = "allrounder",                         -- Key must exist in models
  temperature = 0.7,                                    -- Global fallbacks
  max_tokens = 4096,
  top_p = 0.8,
  scripts = { key = "~/path/to/script.sh" },            -- Shell commands to start server
  test_commands = { name = "command with % placeholder" }, -- % = current file
  keymaps = { action = "<leader>key" }                  -- All buffer-local
}
```

## API Surface (llama.cpp)

| Endpoint | Method | Use Case |
|----------|--------|----------|
| `/v1/models` | GET | Model detection (startup + refresh + switch) |
| `/v1/chat/completions` | POST | All chat/completion requests (non-streaming) |

**Request Format** (OpenAI-compatible):
```json
{
  "model": "Nemotron-Bolt-E4B Q5_K...",
  "messages": [{ "role": "user", "content": "..." }],
  "stream": false,
  "temperature": 0.7,
  "max_tokens": 4096,
  "top_p": 0.8
}
```

**Vision Request** (multimodal):
```json
{
  "messages": [{
    "role": "user",
    "content": [
      { "type": "text", "text": "Describe this" },
      { "type": "image_url", "image_url": { "url": "data:image/png;base64,..." } }
    ]
  }]
}
```

## Key Algorithms (Observed in Code)

### 1. Model Detection (`detect_running_model`)
```
GET /v1/models (2s timeout)
  → Parse JSON response
  → Extract model filename from data[0].id (strip path, .gguf)
  → Fuzzy match against config.models keys:
      - Explicit: "llava" → vision, "nemotron" → allrounder, "qwen3.*8b" → coder, "qwen2.5" → specialist, "qwen3.5" → efficient
      - Fallback: substring match of filename in display name
  → Set state.detected_model, return key + name
```

### 2. Message Queue (`send_prompt` + `_send_with_file`)
- Sequential processing: `state.sending` flag + `state.queue` array
- Each request writes JSON to temp file → `curl -d @file` (avoids E2BIG for base64 images)
- Callback chains: response → append to history → user callback → process next queue item
- Temp file cleanup in all paths (success + error)

### 3. Server Lifecycle (`start_server` / `kill_server`)
```
kill_server():
  → kill -9 state.server_pid (if tracked)
  → pkill -f "llama serve" (catch-all)

start_server(key):
  → kill_server()
  → jobstart bash -c "cd ~ && script.sh && sleep 2 && pgrep -f 'llama serve'"
  → Capture PID from stdout
  → defer 3s → GET /v1/models health check
```

### 4. Test Output Truncation (`truncate_test_output`)
- Preserves: summary lines (Tests run:, BUILD, ERROR, FAILURE, Failed tests:, WARNING)
- Captures failure blocks: up to 30 lines after "failed"/"error"/"assertionerror"/"expect"/"but was"
- Falls back to last 40 lines if no key lines found
- Hard cap: 3000 chars

## Conventions (Observed)

### Error Handling
- **No exceptions** — uses `pcall` for JSON decode, checks `result.code` from `vim.system`
- **User-facing errors**: `vim.notify(..., vim.log.levels.ERROR/WARN/INFO)`
- **Graceful degradation**: Server not running → show startup scripts, allow manual switch
- **No retry logic** for failed requests (queue pauses on error, user must re-send)

### Async / Non-blocking
- **All I/O via `vim.system`** (Neovim 0.10+) — callbacks scheduled on main loop via `vim.schedule`
- **Zero `vim.fn.system()`** (blocking) — correctly avoided
- **Temp files for large payloads** — base64 images can exceed argv limits

### UI Patterns
- **Floating windows**: `relative="editor"`, `style="minimal"`, `border="rounded"`
- **Chat buffer**: `modifiable=false`, `readonly=true` except during `write_to_buf`
- **Keymaps**: Buffer-local (`{ buffer = buf }`), set in `setup_keymaps()`, cleaned on `new_chat()`
- **Input prompts**: `vim.ui.input` for text, `vim.ui.select` for model/test command picker

### Code Style
- Indent: 2 spaces
- Functions: `local function name()` (private), `function M.name()` (public)
- Tables: trailing commas in multi-line
- Strings: double quotes
- Comments: `--` inline, `--[[ ]]` blocks for sections

## Signals / Active Considerations

### Consistency Gaps
1. **Duplicate queue processing logic**: `send_prompt` and `_send_with_file` share ~50 lines of nearly identical callback code
2. **Mixed async styles**: `vim.system` (modern) for HTTP, but `vim.fn.jobstart` (legacy) for server scripts
3. **Two chat creation paths**: `chat()` and `new_chat()` both create buffers/windows with slightly different initialization

### Debt Hotspots
1. **`send_prompt` / `_send_with_file`** (~120 lines combined) — largest functions, queue + HTTP + JSON + temp file + callback chaining
2. **`detect_running_model`** (~60 lines) — complex fuzzy matching logic hardcoded for 5 specific models
3. **`run_tests`** (~60 lines) — command substitution, truncation, prompt building all in one function

### Integration Points
- **User-provided shell scripts** for server startup — plugin executes blindly, no validation
- **llama.cpp OpenAI-compatible API** — assumes specific response shape (`data[0].id`, `choices[0].message.content`)
- **Neovim 0.10+ APIs** — `vim.system`, `vim.json`, `vim.base64`, `vim.ui.select` — won't work on older Neovim

### Conventions (Enforced by Code)
- **Single entry point**: `require("custom_ai").setup()` required before use
- **Config-driven**: All behavior customizable via `setup(opts)` — no hardcoded values in features
- **State isolation**: Module-scoped `state`/`config` — no global pollution
- **Cleanup discipline**: Temp files removed in all callback paths; buffers/windows closed on `new_chat()`

## Testing Strategy (Observed)
- **No automated tests** — manual integration testing only
- **Validation scenarios** (from code paths):
  - Server detection on startup (`check_server_on_startup`)
  - Model switch → server restart → health check
  - Chat send → queue → response → buffer append
  - Vision: image → base64 → temp file → curl → response
  - Edit file/selection → prompt → response → buffer replace
  - Test run → command exec → truncate → AI analysis → chat

## Build / Distribution
- **No build step** — pure Lua
- **Installation**: lazy.nvim spec or manual copy to `~/.config/nvim/lua/custom_ai/init.lua`
- **Version**: Git tags only