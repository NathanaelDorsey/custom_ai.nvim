# custom_ai.nvim

Local **llama.cpp** AI integration for Neovim — connect directly to a `llama-server` instance running on your machine.

Designed for single-GPU setups (e.g. 8GB VRAM) where you run one model at a time on a single port, switching between specialized models as needed.

## Features

| Feature | Description |
|---------|-------------|
| **Auto-detection** | Queries `GET /v1/models` to detect which model is running |
| **Model switching** | Kills old server, starts new one, verifies health |
| **Vision support** | Sends `image_url` content parts for multimodal models (LLaVA, etc.) |
| **Message queue** | Prevents overlapping requests; messages processed in order |
| **Read-only chat** | Toggle show/hide chat buffer; responses persist while closed |
| **File-aware asking** | Send current file content + question to AI |
| **Code editing** | Edit whole file or highlighted selection with full-file context |
| **Test analysis** | Run tests, truncate output, send to AI for analysis |
| **Configurable** | Models, scripts, keymaps, server URL all configurable via `setup()` |

## Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/custom_ai.nvim",
  config = function()
    require("custom_ai").setup({
      server = { host = "127.0.0.1", port = 9931 },
      models = {
        allrounder = "My Model (allrounder: 65K, reasoning, tools)",
        coder      = "My Coder Model (coder: 24K, reasoning, tools)",
        vision     = "LLaVA-NeXT-8B Q6_K (vision: 4K, multimodal, OCR)",
      },
      scripts = {
        allrounder = "~/llama/scripts/start-allrounder.sh",
        coder      = "~/llama/scripts/start-coder.sh",
        vision     = "~/llama/scripts/start-vision.sh",
      },
    })

    vim.keymap.set("n", "<leader>.", require("custom_ai").chat)
  end,
}
```

### Manual

Copy `lua/custom_ai/init.lua` into your Neovim config (e.g. `~/.config/nvim/lua/custom_ai/init.lua`):

```lua
local custom_ai = require("custom_ai")
custom_ai.setup({
  server = { host = "127.0.0.1", port = 9931 },
  -- ... see Configuration below
})

vim.keymap.set("n", "<leader>.", custom_ai.chat)
```

## Configuration

Call `require("custom_ai").setup({ ... })` with any of these options:

```lua
require("custom_ai").setup({
  -- Server connection
  server = {
    host = "127.0.0.1",
    port = 9931,
  },

  -- Model definitions: key -> display name
  -- Used for auto-detection matching and display
  models = {
    allrounder = "Nemotron-Bolt-E4B Q5_K (allrounder: 65K, reasoning, tools)",
    coder      = "Qwen3 8B Q4 (coder: 24K, reasoning, tools)",
    specialist = "Qwen2.5-Coder 7B Q6_K Instruct (specialist: 32K native)",
    efficient  = "Qwen3.5 4B Q8 (efficient: 16K, reasoning, tools)",
    vision     = "LLaVA-NeXT-8B Q6_K (vision: 4K, multimodal, OCR)",
  },

  -- Per-model generation parameters
  model_config = {
    allrounder = { temperature = 0.7, top_p = 0.8, max_tokens = 4096 },
    coder      = { temperature = 0.3, top_p = 0.9, max_tokens = 8192 },
    specialist = { temperature = 0.2, top_p = 0.95, max_tokens = 8192 },
    efficient  = { temperature = 0.5, top_p = 0.9, max_tokens = 2048 },
    vision     = { temperature = 0.4, top_p = 0.9, max_tokens = 4096 },
  },

  default_model = "allrounder",
  temperature = 0.7,
  max_tokens  = 4096,
  top_p       = 0.8,

  -- Startup scripts (run these in a terminal to start llama-server)
  scripts = {
    allrounder = "~/llama/scripts/start-allrounder.sh",
    coder      = "~/llama/scripts/start-coder.sh",
    specialist = "~/llama/scripts/start-specialist.sh",
    efficient  = "~/llama/scripts/start-efficient.sh",
    vision     = "~/llama/scripts/start-vision.sh",
  },

  -- Test commands for <leader>at
  test_commands = {
    python = "python3 %",
    bash   = "bash %",
    java   = "javac % && java ${1:r}",
    node   = "node %",
    go     = "go run %",
    rust   = "rustc % && ./${1:r}",
    pytest = "pytest",
  },

  -- Keymaps (all use <leader>a prefix by default)
  keymaps = {
    send_msg    = "<leader>as",   -- Send message (text only)
    vision_msg  = "<leader>av",   -- Send message + image (vision)
    new_chat    = "<leader>an",   -- New chat (clear history)
    toggle_chat = "<leader>.",    -- Toggle chat window
    run_tests   = "<leader>at",   -- Run tests -> AI
    edit_code   = "<leader>ae",   -- Edit whole file with AI
    ask_file    = "<leader>af",   -- Ask about current file
    edit_sel    = "<leader>ah",   -- Edit highlighted selection
    show_scripts= "<leader>ai",   -- Show startup scripts reminder
  },
})
```

## Keymaps (default)

All AI keymaps use `<leader>a` as a prefix (except toggle which uses `<leader>.`). Keymaps are **buffer-local** (only work inside the AI chat window):

| Key | Action |
|-----|--------|
| `<leader>.` | Toggle AI chat window (global) |
| `<leader>as` | Send message (text only) |
| `<leader>av` | Send message + image (vision models) |
| `<leader>af` | Ask AI about current file |
| `<leader>ae` | Edit whole file with AI |
| `<leader>ah` | AI edit highlighted/visual selection |
| `<leader>at` | Run tests → AI analysis |
| `<leader>ai` | Show startup scripts reminder |
| `<leader>an` | New chat (clear history) |

**Lua functions** (call via `:lua require("custom_ai").function_name()`):

| Function | Action |
|----------|--------|
| `switch_model()` | Switch model (kills old server, starts new one) |
| `refresh_model()` | Re-query server for current model |

## Workflow

1. **Start a server** in a terminal:
   ```bash
   ~/llama/scripts/start-allrounder.sh
   ```

2. **Open Neovim** — the plugin auto-detects the running model on startup

3. **Open chat**: `<leader>.`

4. **Send a message**: `<leader>as` (or `<leader>av` for vision with an image)

5. **Switch models**: Call `:lua require("custom_ai").switch_model()` from a terminal-started server

## Requirements

- Neovim 0.10+
- A running `llama-server` instance (from [llama.cpp](https://github.com/ggerganov/llama.cpp))
- `curl` available in PATH
- `bash` available for starting server scripts
