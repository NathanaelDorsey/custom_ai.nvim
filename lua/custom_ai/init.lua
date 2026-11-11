-- custom_ai.nvim
-- Local llama.cpp AI integration for Neovim
-- Connects to a llama.cpp server (e.g. llama-server on port 9931)
--
-- Features:
--   * Auto-detects running model via /v1/models
--   * Model switching with server restart
--   * Vision support (image_url content parts for LLaVA, etc.)
--   * Message queue (prevents overlapping requests)
--   * Read-only chat buffer with toggle show/hide
--   * File-aware asking, code editing, selection editing
--   * Test output truncation to fit context window
--   * AI-powered inline completion via blink.cmp
--
-- Usage:
--   local custom_ai = require("custom_ai")
--   custom_ai.setup({
--     server = { host = "127.0.0.1", port = 9931 },
--     models = { ... },
--     scripts = { ... },
--     keymaps = { ... },
--   })
--   vim.keymap.set("n", "<leader>.", custom_ai.chat)

local M = {}

-- ---------------------------------------------------------------------------
-- Default configuration
-- ---------------------------------------------------------------------------

local defaults = {
  -- Server connection
  server = {
    host = "127.0.0.1",
    port = 9931,
  },

  -- Model definitions: key -> human-readable name
  -- Used for auto-detection matching and display
  models = {
    allrounder = "Nemotron-Bolt-E4B Q5_K (allrounder: 65K, reasoning, tools)",
    coder      = "Qwen3 8B Q4 (coder: 24K, reasoning, tools)",
    specialist = "Qwen2.5-Coder 7B Q6_K Instruct (specialist: 32K native, best code)",
    efficient  = "Qwen3.5 4B Q8 (efficient: 16K, reasoning, tools)",
    vision     = "LLaVA-NeXT-8B Q6_K (vision: 4K, multimodal, OCR)",
  },

  -- Per-model generation parameters
  model_config = {
    allrounder = { temperature = 0.7, top_p = 0.8, max_tokens = 4096, completion = { max_lines = 1, temperature = 0.2, max_tokens = 64, stop_sequences = { "\n" } } },
    coder      = { temperature = 0.3, top_p = 0.9, max_tokens = 8192, completion = { max_lines = 10, temperature = 0.2, max_tokens = 256, stop_sequences = { "\n" } } },
    specialist = { temperature = 0.2, top_p = 0.95, max_tokens = 8192, completion = { max_lines = 20, temperature = 0.2, max_tokens = 512, stop_sequences = { "\n" } } },
    efficient  = { temperature = 0.5, top_p = 0.9, max_tokens = 2048, completion = { max_lines = 5, temperature = 0.2, max_tokens = 128, stop_sequences = { "\n" } } },
    vision     = { temperature = 0.4, top_p = 0.9, max_tokens = 4096, completion = { max_lines = 1, temperature = 0.3, max_tokens = 64, stop_sequences = { "\n" } } },
  },

  -- Default model key (must exist in `models`)
  default_model = "allrounder",

  -- Global fallback generation parameters
  temperature = 0.7,
  max_tokens  = 4096,
  top_p       = 0.8,

  -- Vision detection: API probe on/off + filename-fallback keyword patterns
  vision_probe = true,
  vision_keywords = { "llava", "bakllava", "llava-next", "llava-1.5", "llava-1.6", "vision" },

  -- Context gathering for completions (LSP + treesitter)
  context = {
    max_tokens = 2000,
    include_imports = true,
    include_types = true,
    include_tests = true,
    max_related_files = 3,
  },

  -- Startup scripts: key -> shell command (run in terminal to start llama-server)
  scripts = {
    allrounder = "./llm-allrounder.sh",
    coder      = "./llm-coder.sh",
    specialist = "./llm-specialist.sh",
    efficient  = "./llm-efficient.sh",
    vision     = "./llm-vision.sh",
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
    completion_trigger = "<C-space>",   -- Manual AI completion trigger (insert mode)
  },

  -- Keymap scope: true = global (work anywhere), false = buffer-local (chat window only)
  global_keymaps = true,

  -- Completion configuration
  completion = {
    enabled = true,
    keymap = "<C-space>",
    trigger_chars = {},
    max_items = 5,
  },
}

-- ---------------------------------------------------------------------------
-- Module state
-- ---------------------------------------------------------------------------

local state = {
  buf = nil,
  win = nil,
  messages = {},
  queue = {},
  sending = false,
  detected_model = nil,
  detected_vision = false,
  server_pid = nil,
  current_model_key = nil,
}

local config = {}

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

function M.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Validate default_model exists
  if config.models and config.default_model and not config.models[config.default_model] then
    vim.notify("custom_ai.nvim: default_model '" .. config.default_model .. "' not found in models config", vim.log.levels.WARN)
    config.default_model = next(config.models)
  end

  state.current_model_key = config.default_model

  -- Initialize completion module with config/state refs
  local completion = require("custom_ai.completion")
  completion.set_refs(config, state)

  -- Register blink.cmp source if completion enabled and blink.cmp available
  if config.completion and config.completion.enabled then
    local ok, blink = pcall(require, "blink.cmp")
    if ok then
      -- Merge custom_ai source into user's blink.cmp sources
      local sources = blink.config and blink.config.sources or {}
      sources.default = sources.default or {}
      -- Add custom_ai to default sources if not already present
      local has_custom_ai = false
      for _, src in ipairs(sources.default) do
        if src == "custom_ai" then has_custom_ai = true end
      end
      if not has_custom_ai then
        table.insert(sources.default, "custom_ai")
      end
      sources.providers = sources.providers or {}
      sources.providers.custom_ai = {
        name = "custom_ai",
        module = "custom_ai.completion",
        enabled = true,
      }
      -- Update blink.cmp config
      blink.setup({ sources = sources })
    else
      vim.notify("custom_ai.nvim: blink.cmp not found, completion disabled", vim.log.levels.WARN)
    end
  end

  -- Set up insert-mode completion trigger keymap
  local km = config.keymaps
  if km.completion_trigger then
    vim.keymap.set("i", km.completion_trigger, function()
      local ok, blink = pcall(require, "blink.cmp")
      if ok then
        blink.show({ providers = { "custom_ai" } })
      else
        vim.notify("custom_ai.nvim: blink.cmp not available for completion", vim.log.levels.WARN)
      end
    end, { desc = "Trigger AI completion" })
  end

  -- Always set up keymaps that work from anywhere (model mgmt, file ops, tests)
  M.setup_global_keymaps()

  -- Set up chat-window keymaps as global or buffer-local based on config
  if config.global_keymaps ~= false then
    M.setup_chat_keymaps_global()
  end

  -- Always create user command for opening chat (works regardless of global_keymaps)
  vim.api.nvim_create_user_command("AIChat", M.chat, { desc = "Open AI chat window" })
end

-- Set up keymaps that work from any buffer (model mgmt, file ops, tests)
function M.setup_global_keymaps()
  local km = config.keymaps

  vim.keymap.set("n", km.switch_model, M.switch_model, { desc = "Switch AI model" })
  vim.keymap.set("n", km.refresh_model, M.refresh_model, { desc = "Refresh model detection" })
  vim.keymap.set("n", km.ask_file, M.ask_file, { desc = "Ask AI about current file" })
  vim.keymap.set("n", km.run_tests, M.run_tests, { desc = "Run tests -> AI analysis" })
  vim.keymap.set("n", km.edit_code, M.edit_code, { desc = "Edit whole file with AI" })
  vim.keymap.set("n", km.edit_sel, M.edit_selection, { desc = "AI edit highlighted selection" })
  vim.keymap.set("n", km.show_scripts, M.show_scripts, { desc = "Show AI startup scripts" })
end

-- Set up chat-window keymaps as global (when global_keymaps=true)
function M.setup_chat_keymaps_global()
  local km = config.keymaps

  vim.keymap.set("n", km.toggle_chat, M.chat, { desc = "Toggle AI chat window" })
  vim.keymap.set("n", km.new_chat, M.new_chat, { desc = "New AI chat (clear history)" })
  -- send_msg and vision_msg are context-dependent; defined in setup_keymaps for chat buffer
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function api_url()
  return string.format("http://%s:%d/v1/chat/completions", config.server.host, config.server.port)
end

local function models_url()
  return string.format("http://%s:%d/v1/models", config.server.host, config.server.port)
end

-- Encode a local image file to a base64 data URL for vision models
local function image_to_data_url(image_path)
  local file = io.open(image_path, "rb")
  if not file then
    vim.notify("custom_ai.nvim: Cannot read image: " .. image_path, vim.log.levels.WARN)
    return nil
  end
  local data = file:read("*a")
  file:close()

  local ext = image_path:match("%.([%w]+)$") or ""
  ext = ext:lower()
  local mime = "image/jpeg"
  if ext == "png" then mime = "image/png"
  elseif ext == "gif" then mime = "image/gif"
  elseif ext == "webp" then mime = "image/webp"
  elseif ext == "bmp" then mime = "image/bmp"
  elseif ext == "jpg" or ext == "jpeg" then mime = "image/jpeg"
  end

  local b64 = vim.base64.encode(data)
  return string.format("data:%s;base64,%s", mime, b64)
end

-- Kill existing llama.cpp server
local function kill_server()
  if state.server_pid then
    vim.fn.jobstart({ "kill", "-9", tostring(state.server_pid) }, { detach = true })
    state.server_pid = nil
    vim.notify("custom_ai.nvim: Stopped previous llama.cpp server", vim.log.levels.INFO)
  end
  vim.fn.jobstart({ "pkill", "-f", "llama serve" }, { detach = true })
end

-- Start llama.cpp server for a model key
local function start_server(model_key)
  local script = config.scripts and config.scripts[model_key]
  if not script then
    vim.notify("custom_ai.nvim: No startup script for model: " .. tostring(model_key), vim.log.levels.ERROR)
    return false
  end

  kill_server()
  vim.notify("custom_ai.nvim: Starting server: " .. script, vim.log.levels.INFO)

  local job_id = vim.fn.jobstart({ "bash", "-c", "cd ~ && " .. script .. " && sleep 2 && pgrep -f 'llama serve' | head -1" }, {
    on_stdout = function(_, data)
      if data and data[1] and data[1] ~= "" then
        local pid = tonumber(data[1])
        if pid then
          state.server_pid = pid
          vim.notify("custom_ai.nvim: llama.cpp server started (PID: " .. pid .. ")", vim.log.levels.INFO)
        end
      end
    end,
    on_stderr = function(_, data)
      if data and data[1] and data[1] ~= "" then
        vim.notify("custom_ai.nvim: Server stderr: " .. data[1], vim.log.levels.WARN)
      end
    end,
    detach = false,
  })

  vim.defer_fn(function()
    local verify_url = models_url()
    vim.system({ "curl", "-s", verify_url }, { text = true }, function(result)
      vim.schedule(function()
        if result.code == 0 and result.stdout and result.stdout:match("models") then
          vim.notify("custom_ai.nvim: Server ready: " .. tostring(config.models[model_key]), vim.log.levels.INFO)
        else
          vim.notify("custom_ai.nvim: Server started but not responding yet", vim.log.levels.WARN)
        end
      end)
    end)
  end, 3000)

  return true
end

-- Detect running server and get model name
local function detect_running_model()
  local result = vim.system({ "curl", "-s", "-m", "2", models_url() }, { text = true }):wait()

  if result.code == 0 and result.stdout and result.stdout ~= "" then
    local ok, data = pcall(vim.json.decode, result.stdout)
    if ok and data and data.data and data.data[1] and data.data[1].id then
      local model_id = data.data[1].id or ""
      local model_filename = model_id:match("([^/]+)%.gguf$") or model_id
      local filename_lower = model_filename:lower()
      local filename_no_ext = filename_lower:gsub("%.gguf$", "")

      for key, name in pairs(config.models) do
        local name_lower = name:lower()
        local matched = false

        -- Explicit filename-based matching (checked first to avoid false positives)
        if key == "vision" and filename_lower:find("llava") then
          matched = true
        elseif key == "allrounder" and filename_lower:find("nemotron") then
          matched = true
        elseif key == "coder" and filename_lower:find("qwen3") and filename_lower:find("8b") then
          matched = true
        elseif key == "specialist" and filename_lower:find("qwen2%.5") then
          matched = true
        elseif key == "efficient" and filename_lower:find("qwen3%.5") then
          matched = true
        end

        -- Fallback: fuzzy name matching (filename in name only)
        if not matched then
          if name_lower:find(filename_no_ext, 1, true) then
            matched = true
          end
        end

        if matched then
          state.detected_model = key
          return key, name, model_id
        end
      end

      state.detected_model = model_id
      return model_id, model_id, model_id
    end
  end

  state.detected_model = nil
  return nil, "no model running", nil
end

-- Strip path and .gguf extension from a model id, returning the bare filename
local function parse_model_filename(model_id)
  if not model_id or model_id == "" then return nil end
  local filename = model_id:match("([^/]+)%.gguf$") or model_id:match("([^/]+)$")
  if not filename or filename == "" then return nil end
  return filename:gsub("%.gguf$", "")
end

-- Asynchronously fetch the running model id from GET /v1/models
local function fetch_model_id(on_complete)
  vim.system({ "curl", "-s", "-m", "2", models_url() }, { text = true }, function(result)
    vim.schedule(function()
      local model_id = nil
      if result.code == 0 and result.stdout and result.stdout ~= "" then
        local ok, data = pcall(vim.json.decode, result.stdout)
        if ok and data and data.data and data.data[1] and data.data[1].id then
          model_id = data.data[1].id
        end
      end
      on_complete(model_id)
    end)
  end)
end

-- Detect vision capability from the model filename using config.vision_keywords.
-- Strips path and .gguf extension, then does a case-insensitive substring
-- match against each keyword (both lowered). Returns result via on_complete(vision_ok).
-- If model_id is not provided, fetches it asynchronously from /v1/models.
local function detect_vision_from_filename(model_id, on_complete)
  if not model_id or model_id == "" then
    fetch_model_id(function(fetched)
      detect_vision_from_filename(fetched, on_complete)
    end)
    return
  end

  local filename = parse_model_filename(model_id)
  if not filename or filename == "" then
    if on_complete then on_complete(false) end
    return
  end

  local filename_lower = filename:lower()
  for _, keyword in ipairs(config.vision_keywords or {}) do
    if filename_lower:find(keyword:lower(), 1, true) then
      if on_complete then on_complete(true) end
      return
    end
  end
  if on_complete then on_complete(false) end
end

-- Build a minimal vision probe payload with a dummy image_url content part
local function probe_request_payload(model_id)
  local dummy_image = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
  return vim.json.encode({
    model = model_id,
    messages = {
      { role = "user", content = { { type = "image_url", image_url = { url = dummy_image } } } },
    },
    stream = false,
    max_tokens = 1,
  })
end

-- Write JSON payload to a temp file, return the path or nil
local function write_temp_json(payload)
  local tmp_file = vim.fn.tempname() .. "_vision_probe.json"
  local f = io.open(tmp_file, "w")
  if not f then return nil end
  f:write(payload)
  f:close()
  return tmp_file
end

-- POST probe payload to the chat API asynchronously; invoke on_complete(vision_ok)
local function make_probe_request(payload, on_complete)
  local tmp_file = write_temp_json(payload)
  if not tmp_file then
    vim.schedule(function() on_complete(false) end)
    return
  end

  vim.system(
    { "curl", "-s", "-X", "POST", api_url(), "-H", "Content-Type: application/json", "-d", "@" .. tmp_file },
    { text = true, timeout = 500 },
    function(result)
      vim.schedule(function()
        os.remove(tmp_file)

        local vision_ok = false
        if result.code == 0 and result.stdout and result.stdout ~= "" then
          local ok, data = pcall(vim.json.decode, result.stdout)
          if ok and data and not data.error and data.choices then
            vision_ok = true
          end
        end
        on_complete(vision_ok)
      end)
    end
  )
end

-- Probe vision capability via the API: sends a minimal chat request with a
-- dummy image_url content part. Runs asynchronously via vim.system callback.
-- Invokes on_complete(vision_ok) when the probe settles.
local function detect_vision_via_probe(model_id, on_complete)
  local payload = probe_request_payload(model_id)
  make_probe_request(payload, on_complete)
end

-- Detect vision capability: API probe first, filename fallback second.
--   config.vision_probe == true  → probe API; on success return true
--                                 on failure/timeout → warn + filename fallback
--   config.vision_probe == false → skip probe, warn + filename fallback
-- Sets state.detected_vision and invokes on_complete(vision_ok).
local function detect_vision_capability(model_id, on_complete)
  local function use_fallback()
    vim.notify("custom_ai.nvim: Using filename fallback for vision detection", vim.log.levels.WARN)
    detect_vision_from_filename(model_id, function(vision)
      state.detected_vision = vision
      if on_complete then on_complete(vision) end
    end)
  end

  if not model_id then
    state.detected_vision = false
    if on_complete then on_complete(false) end
    return
  end

  if config.vision_probe == false then
    return use_fallback()
  end

  detect_vision_via_probe(model_id, function(vision_ok)
    if vision_ok then
      state.detected_vision = true
      if on_complete then on_complete(true) end
    else
      use_fallback()
    end
  end)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function M.check_server_on_startup()
  local key, name, model_id = detect_running_model()
  if key then
    for k, v in pairs(config.models) do
      if v == name or name:find(k) then
        config.default_model = v
        state.current_model_key = k
        break
      end
    end
    if not config.default_model:find(name) then
      config.default_model = name
    end

    -- Detect vision capability (API probe first, filename fallback)
    detect_vision_capability(model_id, function(has_vision)
      state.detected_vision = has_vision
      vim.notify("custom_ai.nvim: Vision: " .. (has_vision and "enabled" or "disabled"), vim.log.levels.INFO)
    end)

    vim.notify("custom_ai.nvim: Server detected: " .. config.default_model, vim.log.levels.INFO)
  else
    config.default_model = "no model running"
    local lines = {
      "=== AI Server Not Running ===",
      "No llama.cpp server detected on " .. config.server.host .. ":" .. config.server.port,
      "",
      "Start one of these scripts in a terminal:",
    }
    for key, script in pairs(config.scripts) do
      table.insert(lines, "  " .. script .. "  # " .. key)
    end
    table.insert(lines, "")
    table.insert(lines, "Vision: disabled")
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Local AI" })
  end
end

function M.refresh_model()
  local key, name = detect_running_model()
  if key then
    for k, v in pairs(config.models) do
      if v == name or name:find(k) then
        config.default_model = v
        state.current_model_key = k
        break
      end
    end
    if not config.default_model:find(name) then
      config.default_model = name
    end
    vim.notify("custom_ai.nvim: Detected model: " .. config.default_model, vim.log.levels.INFO)
  else
    config.default_model = "no model running"
    vim.notify("custom_ai.nvim: No llama.cpp server running on " .. config.server.host .. ":" .. config.server.port, vim.log.levels.WARN)
  end
  return config.default_model
end

function M.switch_model()
  local choices = {}
  for key, name in pairs(config.models) do
    table.insert(choices, key .. ": " .. name)
  end

  vim.ui.select(choices, {
    prompt = "Select model (current: " .. tostring(config.default_model) .. "):",
  }, function(choice)
    if not choice then return end

    local key = choice:match("^(%w+):")
    if key and config.models[key] then
      local old_model = config.default_model
      config.default_model = config.models[key]
      state.current_model_key = key

      vim.notify("custom_ai.nvim: Switching model... restarting server", vim.log.levels.INFO)
      start_server(key)

      vim.notify("custom_ai.nvim: Model switched to: " .. config.default_model, vim.log.levels.INFO)

      if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        M.write_to_buf(state.buf, state.win, {
          "\n======================",
          "=== Model Changed ===",
          "Old: " .. old_model,
          "New: " .. config.default_model,
          "Server restarting...",
          "======================",
        })
      end

      -- Re-detect vision capability once the new server is up
      vim.defer_fn(function()
        local fresh_key, fresh_name, fresh_model_id = detect_running_model()
        if fresh_key then
          state.detected_model = fresh_key
        end
        detect_vision_capability(fresh_model_id, function(has_vision)
          state.detected_vision = has_vision
          vim.notify("custom_ai.nvim: Vision: " .. (has_vision and "enabled" or "disabled"), vim.log.levels.INFO)
          -- Refresh chat header vision status (SF-1)
          if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
            M.write_to_buf(state.buf, state.win, {
              "Vision: " .. (has_vision and "enabled" or "disabled"),
            })
          end
          -- Rebind keymaps for open chat window
          if state.buf and vim.api.nvim_buf_is_valid(state.buf) and state.win and vim.api.nvim_win_is_valid(state.win) then
            setup_keymaps(state.buf, state.win, state.messages, state.detected_vision)
          end
        end)
      end, 3000)
    else
      vim.notify("custom_ai.nvim: Invalid selection", vim.log.levels.WARN)
    end
  end)
end

function M.show_scripts()
  local lines = { "=== Startup Scripts (run in terminal first) ===" }
  for key, script in pairs(config.scripts) do
    table.insert(lines, key .. ": " .. script)
  end
  table.insert(lines, "")
  table.insert(lines, "Run ONE before using AI:")
  if config.scripts.allrounder then
    table.insert(lines, "  cd ~ && " .. config.scripts.allrounder)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Send a request to llama.cpp with full conversation history (non-blocking async, queued)
-- prompt can be a string (text only) or a table of content parts (for vision: text + image_url)
function M.send_prompt(prompt, callback, conversation_history)
  vim.notify("custom_ai.nvim: AI thinking...", vim.log.levels.INFO)

  local history = conversation_history or state.messages

  local user_content
  if type(prompt) == "table" then
    user_content = prompt
  else
    user_content = { { type = "text", text = prompt } }
  end

  table.insert(history, { role = "user", content = user_content })

  local model_cfg = config.model_config and config.model_config[state.current_model_key] or {}
  local temperature = model_cfg.temperature or config.temperature
  local max_tokens = model_cfg.max_tokens or config.max_tokens
  local top_p = model_cfg.top_p or config.top_p

  local json = vim.json.encode({
    model = config.default_model,
    messages = history,
    stream = false,
    temperature = temperature,
    max_tokens = max_tokens,
    top_p = top_p,
  })

  -- Write JSON to a temp file to avoid E2BIG: argument list too long
  -- (base64-encoded images can make the payload very large)
  local tmp_file = vim.fn.tempname() .. "_ai_payload.json"
  local f = io.open(tmp_file, "w")
  if f then
    f:write(json)
    f:close()
  else
    vim.notify("custom_ai.nvim: Cannot write temp file for AI request", vim.log.levels.ERROR)
    return
  end

  if state.sending then
    table.insert(state.queue, {
      prompt = prompt,
      callback = callback,
      conversation_history = history,
      tmp_file = tmp_file,
    })
    return
  end

  state.sending = true

  vim.system(
    { "curl", "-s", "-X", "POST", api_url(), "-H", "Content-Type: application/json", "-d", "@" .. tmp_file },
    { text = true },
    function(result)
      vim.schedule(function()
        state.sending = false
        os.remove(tmp_file)

        local response = nil
        if result.code ~= 0 then
          vim.notify("custom_ai.nvim: AI request failed (curl error): " .. (result.stderr or "unknown"), vim.log.levels.ERROR)
        elseif result.stdout == "" or result.stdout:match("^%s*$") then
          vim.notify("custom_ai.nvim: AI request failed: empty response from server. Is llama.cpp running on port " .. config.server.port .. "?", vim.log.levels.ERROR)
        else
          local ok, data = pcall(vim.json.decode, result.stdout)
          if not ok then
            vim.notify("custom_ai.nvim: AI response parse error: " .. result.stdout:sub(1, 200), vim.log.levels.ERROR)
          elseif data.error then
            vim.notify("custom_ai.nvim: AI server error: " .. (data.error.message or data.error), vim.log.levels.ERROR)
          else
            response = data.choices and data.choices[1] and data.choices[1].message and data.choices[1].message.content
            if response then
              table.insert(history, { role = "assistant", content = response })
              callback(response)
            else
              vim.notify("custom_ai.nvim: AI returned empty response: " .. vim.inspect(data):sub(1, 200), vim.log.levels.WARN)
            end
          end
        end

        if #state.queue > 0 then
          local next = table.remove(state.queue, 1)
          local next_json = vim.json.encode({
            model = config.default_model,
            messages = next.conversation_history,
            stream = false,
            temperature = temperature,
            max_tokens = max_tokens,
            top_p = top_p,
          })
          local next_tmp = vim.fn.tempname() .. "_ai_payload.json"
          local nf = io.open(next_tmp, "w")
          if nf then
            nf:write(next_json)
            nf:close()
            next.tmp_file = next_tmp
            M._send_with_file(next, next_tmp)
          else
            vim.notify("custom_ai.nvim: Cannot write temp file for queued AI request", vim.log.levels.ERROR)
          end
        end
      end)
    end
  )
end

function M._send_with_file(queue_item, tmp_file)
  state.sending = true
  local model_cfg = config.model_config and config.model_config[state.current_model_key] or {}
  local temperature = model_cfg.temperature or config.temperature
  local max_tokens = model_cfg.max_tokens or config.max_tokens
  local top_p = model_cfg.top_p or config.top_p

  vim.system(
    { "curl", "-s", "-X", "POST", api_url(), "-H", "Content-Type: application/json", "-d", "@" .. tmp_file },
    { text = true },
    function(result)
      vim.schedule(function()
        state.sending = false
        os.remove(tmp_file)

        local response = nil
        if result.code ~= 0 then
          vim.notify("custom_ai.nvim: AI request failed (curl error): " .. (result.stderr or "unknown"), vim.log.levels.ERROR)
        elseif result.stdout == "" or result.stdout:match("^%s*$") then
          vim.notify("custom_ai.nvim: AI request failed: empty response from server.", vim.log.levels.ERROR)
        else
          local ok, data = pcall(vim.json.decode, result.stdout)
          if not ok then
            vim.notify("custom_ai.nvim: AI response parse error: " .. result.stdout:sub(1, 200), vim.log.levels.ERROR)
          elseif data.error then
            vim.notify("custom_ai.nvim: AI server error: " .. (data.error.message or data.error), vim.log.levels.ERROR)
          else
            response = data.choices and data.choices[1] and data.choices[1].message and data.choices[1].message.content
            if response then
              table.insert(queue_item.conversation_history, { role = "assistant", content = response })
              queue_item.callback(response)
            else
              vim.notify("custom_ai.nvim: AI returned empty response: " .. vim.inspect(data):sub(1, 200), vim.log.levels.WARN)
            end
          end
        end

        if #state.queue > 0 then
          local next = table.remove(state.queue, 1)
          local next_json = vim.json.encode({
            model = config.default_model,
            messages = next.conversation_history,
            stream = false,
            temperature = temperature,
            max_tokens = max_tokens,
            top_p = top_p,
          })
          local next_tmp = vim.fn.tempname() .. "_ai_payload.json"
          local nf = io.open(next_tmp, "w")
          if nf then
            nf:write(next_json)
            nf:close()
            next.tmp_file = next_tmp
            M._send_with_file(next, next_tmp)
          else
            vim.notify("custom_ai.nvim: Cannot write temp file for queued AI request", vim.log.levels.ERROR)
          end
        end
      end)
    end
  )
end

function M.split_lines(response)
  local lines = {}
  for line in response:gmatch("([^\n]*)\n?") do
    if line ~= "" or #lines > 0 then
      table.insert(lines, line)
    end
  end
  if #lines == 0 then table.insert(lines, response) end
  return lines
end

function M.write_to_buf(buf, win, text_lines)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  local has_win = win and vim.api.nvim_win_is_valid(win)

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })

  local all_lines = {}
  for _, line in ipairs(text_lines) do
    for sub_line in line:gmatch("([^\n]*)\n?") do
      if sub_line ~= "" or #all_lines > 0 then
        table.insert(all_lines, sub_line)
      end
    end
  end
  if #all_lines == 0 then table.insert(all_lines, "") end
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, all_lines)

  if has_win then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

-- ---------------------------------------------------------------------------
-- Keymaps
-- ---------------------------------------------------------------------------

local function setup_keymaps(buf, win, messages, detected_vision)
  local km = config.keymaps
  local is_global = config.global_keymaps

  -- Helper to set keymap with correct scope
  local function set_keymap(mode, lhs, rhs, opts)
    local keymap_opts = opts or {}
    if not is_global then
      keymap_opts.buffer = buf
    end
    vim.keymap.set(mode, lhs, rhs, keymap_opts)
  end

  -- Send message (text only) - chat-context dependent
  set_keymap("n", km.send_msg, function()
    vim.ui.input({ prompt = "You: " }, function(user_input)
      if not user_input or user_input == "" then return end

      M.write_to_buf(buf, win, { "", "You: " .. user_input, "AI: ..." })

      M.send_prompt(user_input, function(response)
        if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
        M.write_to_buf(buf, win, { "AI: " .. response, "" })
        vim.notify("custom_ai.nvim: AI responded!", vim.log.levels.INFO)
      end, messages)
    end)
  end)

  -- Send message with image (for vision models like LLaVA-NeXT)
  -- Bound only when the running model supports vision; otherwise shows a warning
  if detected_vision then
    set_keymap("n", km.vision_msg, function()
      vim.ui.input({ prompt = "You: " }, function(user_input)
        if not user_input or user_input == "" then return end

        vim.ui.input({ prompt = "Image path: " }, function(img_path)
          if not img_path or img_path == "" then
            vim.notify("custom_ai.nvim: No image path given — sending text only", vim.log.levels.WARN)
            M.send_prompt(user_input, function(response)
              if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
              M.write_to_buf(buf, win, { "", "You: " .. user_input .. " [no image]", "AI: ..." })
              M.write_to_buf(buf, win, { "AI: " .. response, "" })
              vim.notify("custom_ai.nvim: AI responded!", vim.log.levels.INFO)
            end, messages)
            return
          end

          local data_url = image_to_data_url(img_path)
          if not data_url then return end

          local content_parts = {
            { type = "text", text = user_input },
            { type = "image_url", image_url = { url = data_url } },
          }

          M.write_to_buf(buf, win, {
            "", "You: " .. user_input,
            "  [image: " .. img_path .. "]",
            "AI: ...",
          })

          M.send_prompt(content_parts, function(response)
            if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
            M.write_to_buf(buf, win, { "AI: " .. response, "" })
            vim.notify("custom_ai.nvim: AI responded!", vim.log.levels.INFO)
          end, messages)
        end)
      end)
    end)
  else
    set_keymap("n", km.vision_msg, function()
      vim.notify("Vision not supported by current model. Switch to a vision-capable model (e.g., LLaVA) to use image upload.", vim.log.levels.WARN)
    end)
  end

  -- When global_keymaps=false, these need to be buffer-local in chat window
  if not is_global then
    -- New chat
    set_keymap("n", km.new_chat, function()
      if win and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
      end
      if buf and vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end

      local new_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(new_buf, "AI Chat")
      local detected_vision = state.detected_vision
      vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, {
        "=== AI Chat (llama.cpp) ===",
        "Server: " .. api_url(),
        "Model: " .. tostring(config.default_model),
        "Vision: " .. (detected_vision and "enabled" or "disabled"),
        "Press '" .. km.send_msg .. "' to send a message",
        "Press '<leader>av' to send a message + image (vision)",
        "Press '" .. km.edit_code .. "' to edit code in place",
        "Press '" .. km.ask_file .. "' to ask about this file",
        "Press '" .. km.new_chat .. "' to start a NEW chat",
        "Press '" .. km.toggle_chat .. "' to toggle hide/show",
        "",
      })

      local new_win = vim.api.nvim_open_win(new_buf, true, {
        relative = "editor",
        width = math.floor(vim.o.columns * 0.4),
        height = math.floor(vim.o.lines * 0.8),
        row = math.floor(vim.o.lines * 0.1),
        col = math.floor(vim.o.columns * 0.55),
        style = "minimal",
        border = "rounded",
      })

      state.messages = {}
      setup_keymaps(new_buf, new_win, state.messages, detected_vision)

      vim.api.nvim_set_option_value("modifiable", false, { buf = new_buf })
      vim.api.nvim_set_option_value("readonly", true, { buf = new_buf })

      state.buf = new_buf
      state.win = new_win
    end)

    -- Toggle hide/show
    set_keymap("n", km.toggle_chat, function()
      if win and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
      end
      if state.win == win then
        state.win = nil
      end
    end)

    -- Run tests (buffer-local when global_keymaps=false)
    set_keymap("n", km.run_tests, function()
      M.run_tests()
    end)

    -- Edit code in place
    set_keymap("n", km.edit_code, function()
      M.edit_code()
    end)

    -- Edit highlighted/visual selection with AI
    set_keymap("n", km.edit_sel, function()
      M.edit_selection()
    end)

    -- Show startup scripts
    set_keymap("n", km.show_scripts, function()
      M.show_scripts()
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Chat window
-- ---------------------------------------------------------------------------

function M.chat()
  M.refresh_model()

  -- Re-detect vision capability for the current model (SF-2a)
  detect_vision_capability(state.detected_model, function(has_vision)
    state.detected_vision = has_vision
  end)

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    if vim.api.nvim_get_current_win() == state.win then
      pcall(vim.api.nvim_win_close, state.win, true)
      state.win = nil
      return
    end
    vim.api.nvim_set_current_win(state.win)
    return
  end

  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    state.win = vim.api.nvim_open_win(state.buf, true, {
      relative = "editor",
      width = math.floor(vim.o.columns * 0.4),
      height = math.floor(vim.o.lines * 0.8),
      row = math.floor(vim.o.lines * 0.1),
      col = math.floor(vim.o.columns * 0.55),
      style = "minimal",
      border = "rounded",
    })
    local detected_vision = state.detected_vision
    setup_keymaps(state.buf, state.win, state.messages, detected_vision)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "AI Chat")
  local detected_vision = state.detected_vision
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "=== AI Chat (llama.cpp) ===",
    "Server: " .. api_url(),
    "Model: " .. tostring(config.default_model) .. (state.detected_model and " (detected)" or ""),
    "Vision: " .. (detected_vision and "enabled" or "disabled"),
    "Press '" .. config.keymaps.send_msg .. "' to send a message",
    "Press '<leader>av' to send a message + image (vision)",
    "Press '" .. config.keymaps.edit_code .. "' to edit code in place",
    "Press '" .. config.keymaps.ask_file .. "' to ask about this file",
    "Press '" .. config.keymaps.new_chat .. "' to start a NEW chat",
    "Press '" .. config.keymaps.toggle_chat .. "' to toggle hide/show",
    "",
  })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.floor(vim.o.columns * 0.4),
    height = math.floor(vim.o.lines * 0.8),
    row = math.floor(vim.o.lines * 0.1),
    col = math.floor(vim.o.columns * 0.55),
    style = "minimal",
    border = "rounded",
  })

  if not win or not vim.api.nvim_win_is_valid(win) then
    vim.notify("custom_ai.nvim: Failed to create chat window", vim.log.levels.ERROR)
    return
  end

  state.messages = {}
  setup_keymaps(buf, win, state.messages, state.detected_vision)

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = buf })

  state.buf = buf
  state.win = win
end

local function open_chat()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    M.chat()
  end
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    vim.notify("custom_ai.nvim: Could not open chat window", vim.log.levels.ERROR)
    return false
  end
  return true
end

-- ---------------------------------------------------------------------------
-- Features
-- ---------------------------------------------------------------------------

function M.get_file_content()
  local buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local content = table.concat(lines, "\n")
  return file_path, content
end

function M.show_response(response, title)
  local lines = M.split_lines(response)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local height = math.floor(vim.o.lines * 0.3)
  local width = vim.o.columns
  local row = math.max(0, vim.o.lines - height - 1)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = 0,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_buf_set_name(buf, "AI Response - " .. title)
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

function M.ask()
  local buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(buf)
  local file_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

  if not open_chat() then return end

  vim.ui.input({ prompt = "Ask AI: " }, function(input)
    if not input or input == "" then return end

    local full_prompt = "File: " .. file_path .. "\n\nFile content:\n" .. file_content .. "\n\nUser question: " .. input

    vim.notify("custom_ai.nvim: Asking AI...", vim.log.levels.INFO)

    M.send_prompt(full_prompt, function(response)
      if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
      M.write_to_buf(state.buf, state.win, {
        "\n======================",
        "=== Ask AI ===",
        "Q: " .. input,
        "A: " .. response,
        "======================",
      })
      vim.notify("custom_ai.nvim: AI responded!", vim.log.levels.INFO)
    end, state.messages)
  end)
end

function M.ask_file()
  local buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(buf)

  if not file_path or file_path == "" then
    vim.notify("custom_ai.nvim: no file is open rn", vim.log.levels.WARN)
    return
  end

  local display_name = vim.fn.fnamemodify(file_path, ":t")
  local file_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

  if not open_chat() then return end

  vim.ui.input({ prompt = "Ask about " .. display_name .. ": " }, function(input)
    if not input or input == "" then return end

    local full_prompt = "File: " .. file_path .. "\n\nFile content:\n" .. file_content .. "\n\nUser question: " .. input

    vim.notify("custom_ai.nvim: Asking AI...", vim.log.levels.INFO)

    M.send_prompt(full_prompt, function(response)
      if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
      M.write_to_buf(state.buf, state.win, {
        "\n======================",
        "=== Ask File ===",
        "File: " .. display_name,
        "Q: " .. input,
        "A: " .. response,
        "======================",
      })
      vim.notify("custom_ai.nvim: AI responded!", vim.log.levels.INFO)
    end, state.messages)
  end)
end

local function truncate_test_output(output)
  local lines = {}
  for line in output:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end

  local key_lines = {}
  local in_failure_block = false
  local failure_block_count = 0

  for _, line in ipairs(lines) do
    local lower = line:lower()

    if line:match("^Tests run:") or line:match("^BUILD ") or line:match("^%[INFO%] BUILD")
       or line:match("^%[ERROR%]") or line:match("FAILURE") or line:match("ERROR")
       or line:match("Failed tests:") or line:match("tests? failed") or line:match("tests? passed")
       or line:match("^%[WARNING%]") then
      table.insert(key_lines, line)
    end

    if lower:match("failed") or lower:match("error") or lower:match("assertionerror")
       or lower:match("expect") or lower:match("but was") then
      if not in_failure_block then
        in_failure_block = true
        failure_block_count = 0
        table.insert(key_lines, "")
        table.insert(key_lines, "--- FAILURE DETAILS ---")
      end
      if failure_block_count < 30 then
        table.insert(key_lines, line)
        failure_block_count = failure_block_count + 1
      end
    end

    if in_failure_block and not lower:match("failed") and not lower:match("error")
       and not lower:match("assertionerror") and not lower:match("expect")
       and not lower:match("but was") and not lower:match("at ")
       and not lower:match("caused by") then
      in_failure_block = false
    end
  end

  if #key_lines == 0 then
    local start_idx = math.max(1, #lines - 40)
    for i = start_idx, #lines do
      table.insert(key_lines, lines[i])
    end
  end

  local result = table.concat(key_lines, "\n")

  if #result > 3000 then
    result = result:sub(1, 3000) .. "\n... (output truncated)"
  end

  return result
end

function M.run_tests()
  local current_file = vim.fn.expand("%")
  local current_file_no_ext = vim.fn.expand("%:r")

  local function run_test_command(command)
    command = command:gsub("%%", current_file):gsub("%${1:r}", current_file_no_ext)

    local output_file = vim.fn.tempname() .. "_ai_test_output.txt"

    vim.notify("custom_ai.nvim: Running tests: " .. command, vim.log.levels.INFO)

    local result = vim.fn.system(command)
    local exit_code = vim.v.shell_error

    local file = io.open(output_file, "w")
    if file then
      file:write(result)
      file:close()
    end

    local truncated_output = truncate_test_output(result)
    local full_prompt = "Here are the test results from running: " .. command .. "\n\n"
      .. "Exit code: " .. tostring(exit_code) .. "\n\n"
      .. "Test output:\n" .. truncated_output .. "\n\n"
      .. "Please analyze these results and suggest fixes for any failing tests."

    vim.notify("custom_ai.nvim: Tests complete. Sending to AI...", vim.log.levels.INFO)

    M.send_prompt(full_prompt, function(response)
      if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
      M.write_to_buf(state.buf, state.win, {
        "\n======================",
        "=== Test Results ===",
        "Command: " .. command,
        "Exit code: " .. tostring(exit_code),
        "Output file: " .. output_file,
        "AI analysis:",
        response,
        "======================",
      })
      vim.notify("custom_ai.nvim: AI analyzed test results!", vim.log.levels.INFO)
    end, state.messages)
  end

  if not open_chat() then return end

  local test_options = {}
  for name, cmd in pairs(config.test_commands) do
    table.insert(test_options, name .. ": " .. cmd)
  end
  table.insert(test_options, "custom: enter your own command")

  vim.ui.select(test_options, {
    prompt = "Select test command:",
  }, function(choice)
    if not choice then return end

    local cmd
    if choice == "custom: enter your own command" then
      vim.ui.input({ prompt = "Test command: ", default = "pytest" }, function(custom_cmd)
        if not custom_cmd or custom_cmd == "" then return end
        run_test_command(custom_cmd)
      end)
      return
    end

    local _, _, command = choice:find("^%w+: (.+)$")
    cmd = command or choice
    run_test_command(cmd)
  end)
end

function M.edit_code()
  local buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(buf)

  if not file_path or file_path == "" then
    vim.notify("custom_ai.nvim: no file is open rn", vim.log.levels.WARN)
    return
  end

  local display_name = vim.fn.fnamemodify(file_path, ":t")
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  if not open_chat() then return end

  vim.ui.input({ prompt = "Edit instruction for " .. display_name .. ": " }, function(input)
    if not input or input == "" then return end

    local full_prompt = [[You are a code editor. Edit the following file content based on the user's instruction.
Return ONLY the modified file content, no explanations, no markdown code blocks.

File: ]] .. file_path .. [[

Current content:
]] .. content .. [[

Instruction: ]] .. input

    vim.notify("custom_ai.nvim: AI editing " .. display_name .. "...", vim.log.levels.INFO)

    M.send_prompt(full_prompt, function(response)
      if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

      local edited = response:gsub("```%w*\n", ""):gsub("```$", ""):gsub("^```", "")
      local new_lines = vim.split(edited, "\n")

      vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

      vim.notify("custom_ai.nvim: File edited: " .. display_name, vim.log.levels.INFO)
    end, state.messages)
  end)
end

function M.edit_selection()
  local buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(buf)

  if not file_path or file_path == "" then
    vim.notify("custom_ai.nvim: no file is open rn", vim.log.levels.WARN)
    return
  end

  local display_name = vim.fn.fnamemodify(file_path, ":t")

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]
  local start_col = start_pos[3]
  local end_col = end_pos[3]

  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local full_content = table.concat(all_lines, "\n")

  local selected_lines = {}
  if start_line == end_line then
    local line = all_lines[start_line]
    if line then
      table.insert(selected_lines, line:sub(start_col, end_col))
    end
  else
    for i = start_line, end_line do
      local line = all_lines[i]
      if line then
        if i == start_line then
          table.insert(selected_lines, line:sub(start_col))
        elseif i == end_line then
          table.insert(selected_lines, line:sub(1, end_col))
        else
          table.insert(selected_lines, line)
        end
      end
    end
  end

  local selection = table.concat(selected_lines, "\n")

  if not selection or selection == "" then
    vim.notify("custom_ai.nvim: no text selected", vim.log.levels.WARN)
    return
  end

  if not open_chat() then return end

  vim.ui.input({ prompt = "Edit instruction for selection: " }, function(input)
    if not input or input == "" then return end

    local full_prompt = [[You are a code editor. Edit the following SELECTED TEXT based on the user's instruction.

The full file is provided for context (file: ]] .. file_path .. [[). Only modify the selected text, keep everything else the same.
Return ONLY the modified selected text, no explanations, no markdown code blocks.

Full file content:
]] .. full_content .. [[


SELECTED TEXT TO EDIT:
]] .. selection .. [[


Edit instruction: ]] .. input

    vim.notify("custom_ai.nvim: AI editing selection in " .. display_name .. "...", vim.log.levels.INFO)

    M.send_prompt(full_prompt, function(response)
      if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

      local edited = response:gsub("```%w*\n", ""):gsub("```$", ""):gsub("^```", "")
      local new_lines = vim.split(edited, "\n")

      vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
      vim.api.nvim_buf_set_lines(buf, start_line - 1, end_line, false, new_lines)
      vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

      vim.notify("custom_ai.nvim: Selection edited: " .. display_name, vim.log.levels.INFO)
    end, state.messages)
  end)
end

function M.new_chat()
  state.messages = {}
  state.detected_model = nil
  state.detected_vision = false
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
    state.win = nil
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
    state.buf = nil
  end
  vim.notify("custom_ai.nvim: New chat started — history cleared", vim.log.levels.INFO)
end

-- Export detect_running_model for external access
M.detect_running_model = detect_running_model

return M