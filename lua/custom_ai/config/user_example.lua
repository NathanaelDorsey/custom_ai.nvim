--[[
  custom_ai.nvim - User Configuration Example
  ===========================================
  
  Copy this file to your Neovim config directory and customize:
  
  Linux/macOS:  ~/.config/nvim/lua/custom_ai_config.lua
  Windows:      ~/AppData/Local/nvim/lua/custom_ai_config.lua
  
  Then in your lazy.nvim plugin spec:
  
  {
    dir = "/path/to/custom_ai.nvim",
    config = function()
      local user_config = require("custom_ai_config")  -- loads your config
      require("custom_ai").setup(user_config)
    end
  }
  
  Or if using the plugin from a local path with lazy.nvim:
  
  {
    dir = "~/custom_ai.nvim",
    config = function()
      local ok, user_config = pcall(require, "custom_ai_config")
      if not ok then user_config = {} end
      require("custom_ai").setup(user_config)
    end
  }
  
  The plugin provides 5 DEFAULT MODELS (in lua/custom_ai/config/models.lua):
    allrounder, coder, specialist, efficient, vision
  
  Override or add your own below. Keys must match across models, scripts, and model_config.
--]]

return {
  -- ============================================================
  -- SERVER CONFIGURATION
  -- ============================================================
  server = {
    host = "127.0.0.1",
    port = 9931,
    -- Container mode: set to container name (e.g., "cuda-dev") to run llama.cpp
    -- inside a podman/docker container. Set to nil/false to run on host directly.
    -- The plugin will AUTO-START the container if stopped.
    --
    -- Examples:
    --   container = "cuda-dev"     -- podman/distrobox container name
    --   container = "llama-server" -- docker container name
    --   container = nil            -- run llama-server directly on host
    container = nil,
  },

  -- Verbose logging: true = show INFO messages, false = only WARN/ERROR (default: false)
  verbose = false,

  -- ============================================================
  -- MODEL DEFINITIONS
  -- ============================================================
  -- Key = internal identifier (used for scripts, model_config, switching)
  -- Value = display name shown in UI
  -- Override defaults or add your own models here
  models = {
    allrounder = "Nemotron-Bolt-E4B Q5_K (allrounder: 65K, reasoning, tools)",
    coder      = "Qwen3 8B Q4 (coder: 24K, reasoning, tools)",
    specialist = "Qwen2.5-Coder 7B Q6_K Instruct (specialist: 32K native, best code)",
    efficient  = "Qwen3.5 4B Q8 (efficient: 16K, reasoning, tools)",
    vision     = "LLaVA-NeXT-8B Q6_K (vision: 4K, multimodal, OCR)",
    -- Add your own models here:
    -- my_model   = "My Custom Model (context, quantization, etc.)",
  },

  -- ============================================================
  -- STARTUP SCRIPTS
  -- ============================================================
  -- Maps model key -> script path (relative to ~ or absolute)
  -- Scripts should start llama-server and daemonize it.
  -- The plugin calls: bash -c "cd ~ && <script>"
  -- Keys MUST match the models table above
  scripts = {
    allrounder = "llama/scripts/llm-NEMOTRON-allrounder-reasoning-tools-65k.sh",
    coder      = "llama/scripts/llm-QWEN3-8B-coder-reasoning-tools-24k.sh",
    specialist = "llama/scripts/llm-QWEN2.5-CODER-7B-specialist-32k.sh",
    efficient  = "llama/scripts/llm-QWEN3.5-4B-efficient-reasoning-tools-16k.sh",
    vision     = "llama/scripts/llm-llava-next-8b-vision.sh",
    -- my_model   = "llama/scripts/llm-my-model.sh",
  },

  -- ============================================================
  -- PER-MODEL GENERATION PARAMETERS
  -- ============================================================
  -- These override global defaults (temperature, max_tokens, top_p)
  -- Supports nested 'completion' table for inline completion settings
  -- Keys MUST match the models table above
  model_config = {
    -- Example for a coding model:
    -- specialist = {
    --   temperature = 0.3,
    --   top_p = 0.95,
    --   max_tokens = 8192,
    --   completion = { max_lines = 10, temperature = 0.1 }
    -- },
    -- Example for a vision model with longer completions:
    -- vision = {
    --   temperature = 0.4,
    --   top_p = 0.9,
    --   max_tokens = 4096,
    --   completion = { max_lines = 5, temperature = 0.3, max_tokens = 128 }
    -- },
  },

  -- ============================================================
  -- VISION DETECTION
  -- ============================================================
  -- Filename keywords that indicate a vision-capable model.
  -- Used for fallback detection when API probe fails.
  vision_keywords = { "llava", "bakllava", "llava-next", "llava-1.5", "llava-1.6", "vision", "inkling" },

  -- Enable API probe for vision capability (sends test image to /v1/chat/completions)
  -- If false, uses filename fallback only.
  vision_probe = true,

  -- ============================================================
  -- DEFAULT MODEL
  -- ============================================================
  -- Must match a key in 'models' table above
  default_model = "allrounder",

  -- ============================================================
  -- GLOBAL GENERATION DEFAULTS
  -- ============================================================
  temperature = 0.7,
  max_tokens  = 4096,
  top_p       = 0.8,

  -- ============================================================
  -- CONTEXT GATHERING (for inline completion)
  -- ============================================================
  context = {
    max_tokens = 2000,
    include_imports = true,
    include_types = true,
    include_tests = true,
    max_related_files = 3,
  },

  -- ============================================================
  -- TEST COMMANDS
  -- ============================================================
  -- % expands to current file path
  -- ${1:r} expands to file path without extension
  test_commands = {
    python = "python3 %",
    bash   = "bash %",
    java   = "javac % && java ${1:r}",
    node   = "node %",
    go     = "go run %",
    rust   = "rustc % && ./${1:r}",
    pytest = "pytest",
  },

  -- ============================================================
  -- KEYMAPS
  -- ============================================================
  -- All use <leader>a prefix by default
  keymaps = {
    send_msg           = "<leader>as",   -- Send message (text only)
    vision_msg         = "<leader>av",   -- Send message + image (vision models)
    new_chat           = "<leader>an",   -- New chat (clear history)
    toggle_chat        = "<leader>.",    -- Toggle chat window show/hide
    run_tests          = "<leader>at",   -- Run tests -> AI analysis
    edit_code          = "<leader>ae",   -- Edit code in place (whole file)
    ask_file           = "<leader>af",   -- Ask AI about current file
    edit_sel           = "<leader>ah",   -- AI edit highlighted selection
    show_scripts       = "<leader>ai",   -- Show startup scripts reminder
    switch_model       = "<leader>am",   -- Switch AI model
    refresh_model      = "<leader>ar",   -- Refresh model detection
    toggle_completion  = "<leader>ac",   -- Toggle AI completion on/off
    completion_trigger = "<C-space>",    -- Manual AI completion trigger (insert mode)
  },

  -- Keymap scope: true = global (work anywhere), false = buffer-local (chat window only)
  global_keymaps = true,

  -- ============================================================
  -- COMPLETION CONFIGURATION
  -- ============================================================
  completion = {
    enabled = true,
    keymap = "<C-space>",
    trigger_chars = {},
    max_items = 5,
    -- Global defaults (used as base for deep merge)
    temperature = 0.2,
    top_p = 0.8,
    max_tokens = 64,
    stop_sequences = { "\n" },
    max_lines = 1,
    prompt_template = nil,
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
      sql = { max_lines = 5, temperature = 0.1 },
      sh = { max_lines = 3, temperature = 0.1 },
      bash = { max_lines = 3, temperature = 0.1 },
      zsh = { max_lines = 3, temperature = 0.1 },
      fish = { max_lines = 3, temperature = 0.1 },
      dockerfile = { max_lines = 3, temperature = 0.1 },
      toml = { max_lines = 3, temperature = 0.1 },
    },
  },
}