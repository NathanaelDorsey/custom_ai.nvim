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
| **Inline completion** | AI code completions via blink.cmp with project context |
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
    send_msg      = "<leader>as",   -- Send message (text only)
    vision_msg    = "<leader>av",   -- Send message + image (vision)
    new_chat      = "<leader>an",   -- New chat (clear history)
    toggle_chat   = "<leader>.",    -- Toggle chat window
    run_tests     = "<leader>at",   -- Run tests -> AI
    edit_code     = "<leader>ae",   -- Edit whole file with AI
    ask_file      = "<leader>af",   -- Ask about current file
    edit_sel      = "<leader>ah",   -- Edit highlighted selection
    show_scripts  = "<leader>ai",   -- Show startup scripts reminder
    switch_model  = "<leader>am",   -- Switch AI model
    refresh_model = "<leader>ar",   -- Refresh model detection
  },

  -- Keymap scope: true = global (work anywhere), false = buffer-local (chat window only)
  -- Default: true — all keymaps work globally. Set to false to restrict chat keymaps
  -- (send_msg, vision_msg, new_chat, toggle_chat) to the chat window only.
  global_keymaps = true,
})
```

## Completion (Inline AI Code Completion)

The plugin integrates with **blink.cmp** to provide inline AI-powered code completions.

### Setup

Requires [blink.cmp](https://github.com/Saghen/blink.cmp) to be installed and configured:

```lua
-- In your lazy.nvim spec for blink.cmp
{
  "saghen/blink.cmp",
  dependencies = { "your-username/custom_ai.nvim" },
  opts = {
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "custom_ai" },
      providers = {
        custom_ai = {
          name = "custom_ai",
          module = "custom_ai.completion",
          opts = {
            enabled = function()
              return require("custom_ai").config.completion.enabled
            end,
          },
        },
      },
    },
  },
}
```

**Note:** The plugin automatically registers itself as a blink.cmp source when `setup()` is called. You only need to add `"custom_ai"` to your `sources.default` list.

### Configuration

```lua
require("custom_ai").setup({
  -- ... other config

  -- Completion settings
  completion = {
    enabled = true,           -- Enable/disable AI completions
    keymap = "<C-space>",    -- Insert-mode trigger key
    trigger_chars = {},       -- Characters that trigger completion (empty = manual only)
    max_items = 5,            -- Max completion items to show
    timeout_ms = 5000,        -- Request timeout in ms

    -- Filetype-specific overrides (merged on top of model_config.completion)
    filetypes = {
      lua = { max_lines = 10, temperature = 0.1, top_p = 0.95 },
      python = { max_lines = 5, temperature = 0.1, top_p = 0.9 },
      javascript = { max_lines = 8, temperature = 0.2 },
      typescript = { max_lines = 8, temperature = 0.2 },
      go = { max_lines = 10, temperature = 0.15 },
      rust = { max_lines = 15, temperature = 0.15 },
      c = { max_lines = 5, temperature = 0.1 },
      cpp = { max_lines = 5, temperature = 0.1 },
      java = { max_lines = 8, temperature = 0.15 },
      html = { max_lines = 3, temperature = 0.2 },
      css = { max_lines = 3, temperature = 0.2 },
      json = { max_lines = 1, temperature = 0.05 },
      yaml = { max_lines = 3, temperature = 0.1 },
      markdown = { max_lines = 3, temperature = 0.3 },
    },
  },

  -- Per-model completion parameters (merged with filetype overrides)
  model_config = {
    allrounder = { temperature = 0.7, top_p = 0.8, max_tokens = 4096,
      completion = { max_lines = 1, temperature = 0.2, max_tokens = 64, stop_sequences = { "\n" } } },
    coder      = { temperature = 0.3, top_p = 0.9, max_tokens = 8192,
      completion = { max_lines = 10, temperature = 0.2, max_tokens = 256, stop_sequences = { "\n" } } },
    specialist = { temperature = 0.2, top_p = 0.95, max_tokens = 8192,
      completion = { max_lines = 20, temperature = 0.2, max_tokens = 512, stop_sequences = { "\n" } } },
    efficient  = { temperature = 0.5, top_p = 0.9, max_tokens = 2048,
      completion = { max_lines = 5, temperature = 0.2, max_tokens = 128, stop_sequences = { "\n" } } },
    vision     = { temperature = 0.4, top_p = 0.9, max_tokens = 4096,
      completion = { max_lines = 1, temperature = 0.3, max_tokens = 64, stop_sequences = { "\n" } } },
  },

  -- Keymaps
  keymaps = {
    -- ... other keymaps
    completion_trigger = "<C-space>",  -- Trigger AI completion (insert mode)
    toggle_completion  = "<leader>ac", -- Toggle AI completion on/off
  },
})
```

### Usage

1. **Trigger completion**: In insert mode, press `<C-space>` (or your configured `keymaps.completion_trigger`)
2. **Navigate**: Use `<C-n>` / `<C-p>` or arrow keys to select
3. **Accept**: Press `<CR>` or `<Tab>` to insert
4. **Toggle on/off**: Press `<leader>ac` or run `:AICompletionToggle`

### Completion Types

| Model | max_lines | Behavior |
|-------|-----------|----------|
| allrounder | 1 | Single-line only |
| coder | 10 | Multi-line (functions, blocks) |
| specialist | 20 | Multi-line (large blocks) |
| efficient | 5 | Multi-line (small blocks) |
| vision | 1 | Single-line only |

### Project Context

Completions automatically gather project context via LSP and Treesitter:
- **Imports** from other files in the project
- **Type definitions** (classes, interfaces, types)
- **Related functions** referenced near cursor
- **Test files** for the current file

Context is assembled and truncated to fit within `context.max_tokens` (default 2000 tokens).

### Graceful Degradation

- **Server unavailable**: Shows "Error: Server unavailable" in completion menu
- **Timeout**: Shows "Error: Request timeout" after 5s (configurable)
- **Parse errors**: Shows "Error: Parse failed"
- **Empty response**: Shows "Error: Empty response"
- **Auto-retry**: Each trigger attempts a fresh request

### Commands

| Command | Action |
|---------|--------|
| `:AICompletionToggle` | Toggle AI completion on/off |

### Keymaps

| Key | Action | Mode |
|-----|--------|------|
| `<C-space>` | Trigger AI completion | Insert |
| `<leader>ac` | Toggle AI completion | Normal |

---

## Workflow

1. **Start a server** in a terminal:
   ```bash
   ~/llama/scripts/start-allrounder.sh
   ```

2. **Open Neovim** — the plugin auto-detects the running model on startup

3. **Open chat**: `<leader>.` (or run `:AIChat`)

4. **Send a message**: `<leader>as` (or `<leader>av` for vision with an image)

5. **Switch models**: `<leader>am` (or call `:lua require("custom_ai").switch_model()`)

6. **Refresh model detection**: `<leader>ar` (or call `:lua require("custom_ai").refresh_model()`)

> **Note:** `:AIChat` works even when `global_keymaps = false` since it's a command, not a keymap.

## Requirements

- Neovim 0.10+
- A running `llama-server` instance (from [llama.cpp](https://github.com/ggerganov/llama.cpp))
- `curl` available in PATH
- `bash` available for starting server scripts