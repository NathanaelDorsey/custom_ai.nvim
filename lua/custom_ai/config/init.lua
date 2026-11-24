-- custom_ai.nvim Configuration Loader
-- Loads modular config files and provides a unified config table
-- User config (from setup()) is deep-merged on top of these defaults

local M = {}

-- Load a config module safely
local function load_module(name)
  local ok, mod = pcall(require, "custom_ai.config." .. name)
  if not ok then
    vim.notify("custom_ai.nvim: Failed to load config module '" .. name .. "': " .. tostring(mod), vim.log.levels.WARN)
    return {}
  end
  return mod
end

-- Deep merge two tables (user config overrides defaults)
local function deep_merge(defaults, user)
  local result = {}
  for k, v in pairs(defaults) do
    result[k] = v
  end
  for k, v in pairs(user or {}) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

-- Get the complete default configuration
function M.get_defaults()
  return {
    -- Model definitions
    models = load_module("models"),

    -- Startup scripts
    scripts = load_module("scripts"),

    -- Per-model generation parameters
    model_config = load_module("model_config"),

    -- Vision detection keywords (filename patterns)
    vision_keywords = { "llava", "bakllava", "llava-next", "llava-1.5", "llava-1.6", "vision", "inkling" },

    -- Default model key (must exist in models)
    default_model = "allrounder",

    -- Verbose logging: true = show INFO messages, false = only WARN/ERROR
    verbose = false,

    -- Server configuration
    server = {
      host = "127.0.0.1",
      port = 9931,
      -- container: nil/false = run on host, string = podman/docker container name
      container = nil,
    },

    -- Global fallback generation parameters
    temperature = 0.7,
    max_tokens  = 4096,
    top_p       = 0.8,

    -- Vision detection: API probe on/off + filename-fallback keyword patterns
    vision_probe = true,

    -- Context gathering for completions (LSP + treesitter)
    context = {
      max_tokens = 2000,
      include_imports = true,
      include_types = true,
      include_tests = true,
      max_related_files = 3,
    },

    -- Test commands for run_tests()
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

    -- Completion configuration
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
end

-- Merge user config with defaults
function M.merge(user_config)
  local defaults = M.get_defaults()
  return deep_merge(defaults, user_config or {})
end

return M