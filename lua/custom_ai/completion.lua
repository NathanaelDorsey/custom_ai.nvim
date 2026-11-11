-- custom_ai.nvim — blink.cmp completion source
-- Provides AI-powered completions via llama.cpp /v1/completions

local M = {}

-- Completion item kinds (blink.cmp/ LSP compatible)
local CompletionItemKind = {
  Text = 1,
  Method = 2,
  Function = 3,
  Constructor = 4,
  Field = 5,
  Variable = 6,
  Class = 7,
  Interface = 8,
  Module = 9,
  Property = 10,
  Unit = 11,
  Value = 12,
  Enum = 13,
  Keyword = 14,
  Snippet = 15,
  Color = 16,
  File = 17,
  Reference = 18,
  Folder = 19,
  EnumMember = 20,
  Constant = 21,
  Struct = 22,
  Event = 23,
  Operator = 24,
  TypeParameter = 25,
}

local config_ref = nil
local state_ref = nil
local context_module = nil

-- Completion request queue state
local completion_queue = {
  active_handle = nil,
  pending_context = nil,
  pending_callback = nil,
}

function M.set_refs(cfg, st)
  local ctx_mod = require("custom_ai.context")
  context_module = ctx_mod
  config_ref = cfg
  state_ref = st
  context_module.set_config(cfg)
end
-- Pre-flight server check: quick HEAD/GET to /v1/models with 1s timeout
-- Returns true if server is reachable, false otherwise
local function preflight_check(callback)
  local models_url = string.format("http://%s:%d/v1/models", config_ref.server.host, config_ref.server.port)
  local handle = vim.system(
    { "curl", "-s", "-I", "-m", "1", models_url },
    { text = true, timeout = 1000 },
    function(result)
      vim.schedule(function()
        local ok = result.code == 0
        callback(ok)
      end)
    end
  )
end

-- Create an error completion item for graceful degradation
local function make_error_item(label, detail)
  return {
    label = label,
    kind = CompletionItemKind.Text,
    detail = detail,
    insertText = "",
    insertTextFormat = 1, -- Plain text
  }
end

-- Cancel any active completion request
local function cancel_active_request()
  if completion_queue.active_handle then
    completion_queue.active_handle:kill(9)
    completion_queue.active_handle = nil
  end
end

-- Resolve completion config with deep merge:
-- 1. Global completion defaults (config.completion)
-- 2. Model-specific config (config.model_config[key].completion)
-- 3. Filetype-specific overrides (config.completion.filetypes[ft])
local function resolve_completion_config(filetype)
  local model_key = state_ref.current_model_key
  local global_cfg = config_ref.completion or {}

  -- Start with global defaults (excluding meta keys like enabled, keymap, etc.)
  local defaults = {
    temperature = global_cfg.temperature or 0.2,
    top_p = global_cfg.top_p or 0.8,
    max_tokens = global_cfg.max_tokens or 64,
    stop_sequences = global_cfg.stop_sequences or { "\n" },
    max_lines = global_cfg.max_lines or 1,
    prompt_template = global_cfg.prompt_template,
    timeout_ms = global_cfg.timeout_ms or 5000,
  }

  -- Merge model-specific completion config
  local model_cfg = config_ref.model_config and config_ref.model_config[model_key] or {}
  local model_completion = model_cfg.completion or {}
  local resolved = vim.tbl_deep_extend("force", defaults, model_completion)

  -- Merge filetype-specific overrides
  local ft_overrides = global_cfg.filetypes and global_cfg.filetypes[filetype] or {}
  resolved = vim.tbl_deep_extend("force", resolved, ft_overrides)

  -- Fallback to model-level temperature/top_p/max_tokens if not in completion config
  if not model_completion.temperature and model_cfg.temperature then
    resolved.temperature = model_cfg.temperature
  end
  if not model_completion.top_p and model_cfg.top_p then
    resolved.top_p = model_cfg.top_p
  end
  if not model_completion.max_tokens and model_cfg.max_tokens then
    resolved.max_tokens = model_cfg.max_tokens
  end
  -- Also check global config as final fallback
  if not resolved.temperature then
    resolved.temperature = config_ref.temperature or 0.7
  end
  if not resolved.top_p then
    resolved.top_p = config_ref.top_p or 0.8
  end
  if not resolved.max_tokens then
    resolved.max_tokens = config_ref.max_tokens or 4096
  end

  return resolved
end

-- Build the prompt for completion with project context
local function build_prompt(context, project_ctx, resolved_cfg)
  local buf = context.bufnr
  local cursor = context.cursor
  local line = cursor[1]  -- 1-indexed line number
  local col = cursor[2]   -- 0-indexed column

  -- Get 10 lines before cursor line (or fewer if at top of file)
  local start_line = math.max(1, line - 10)
  local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, line - 1, false)
  local prefix = table.concat(lines, "\n")

  -- Get current line up to cursor
  local current_line = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
  local cursor_line_prefix = current_line:sub(1, col)

  local filetype = vim.bo[buf].filetype
  local filename = vim.api.nvim_buf_get_name(buf)
  filename = filename ~= "" and vim.fn.fnamemodify(filename, ":t") or "unknown"

  local max_lines = resolved_cfg.max_lines or 1
  local is_multi_line = max_lines > 1

  -- Use custom prompt template if provided, otherwise use built-in
  local system_instruction
  if resolved_cfg.prompt_template then
    -- Custom template: replace placeholders
    system_instruction = resolved_cfg.prompt_template
      :gsub("{filetype}", filetype)
      :gsub("{filename}", filename)
      :gsub("{max_lines}", tostring(max_lines))
  else
    if is_multi_line then
      system_instruction = string.format(
        "You are a code completion engine. Generate a complete code block for %s.\n" ..
        "Use proper indentation. Output ONLY the code, no explanations, no markdown fences.",
        filetype
      )
    else
      system_instruction = string.format(
        "You are a code completion engine. Complete the current line with a single line of %s code.\n" ..
        "Return ONLY the completion text, no explanations, no markdown, no extra lines.",
        filetype
      )
    end
  end

  -- Include project context if available
  local context_section = ""
  if project_ctx and project_ctx._full and project_ctx._full ~= "" then
    context_section = "\n\nPROJECT CONTEXT:\n" .. project_ctx._full
  end

  local prompt = string.format(
    "%s%s\n\nFile: %s\n\n%s%s",
    system_instruction,
    context_section,
    filename,
    prefix,
    cursor_line_prefix
  )

  return prompt
end

-- Request completion from llama.cpp /v1/completions endpoint
-- context: blink.cmp context (bufnr, cursor, etc.)
-- callback: function(completion_text, error_item) called with parsed completion or error item
function M.request_completion(context, callback)
  -- Cancel any active request before starting a new one
  cancel_active_request()

  -- Gather project context first
  local bufnr = context.bufnr
  local cursor_pos = context.cursor

  context_module.gather_context(bufnr, cursor_pos, function(project_ctx)
    -- Resolve config for current filetype
    local filetype = vim.bo[bufnr].filetype
    local resolved_cfg = resolve_completion_config(filetype)

    local prompt = build_prompt(context, project_ctx, resolved_cfg)

    local temperature = resolved_cfg.temperature
    local max_tokens = resolved_cfg.max_tokens
    local top_p = resolved_cfg.top_p
    local stop_sequences = resolved_cfg.stop_sequences
    local timeout_ms = resolved_cfg.timeout_ms
    local max_lines = resolved_cfg.max_lines

    local json = vim.json.encode({
      model = config_ref.default_model,
      prompt = prompt,
      stream = false,
      temperature = temperature,
      max_tokens = max_tokens,
      top_p = top_p,
      stop = stop_sequences,
    })

    local tmp_file = vim.fn.tempname() .. "_completion_payload.json"
    local f = io.open(tmp_file, "w")
    if not f then
      vim.notify("custom_ai.nvim: Cannot write temp file for completion request", vim.log.levels.ERROR)
      callback(nil, { label = "Error: Cannot write temp file", kind = 1, detail = "AI completion error" })
      return
    end
    f:write(json)
    f:close()

    local completions_url = string.format("http://%s:%d/v1/completions", config_ref.server.host, config_ref.server.port)

    local handle = vim.system(
      { "curl", "-s", "-X", "POST", completions_url, "-H", "Content-Type: application/json", "-d", "@" .. tmp_file },
      { text = true, timeout = timeout_ms },
      function(result)
        vim.schedule(function()
          os.remove(tmp_file)
          completion_queue.active_handle = nil

          local completion_text = nil
          local error_item = nil
          if result.code ~= 0 then
            local err_msg = result.stderr or "unknown"
            if result.code == 124 or err_msg:match("timeout") then
              error_item = { label = "Error: Request timeout", kind = 1, detail = "AI completion timeout" }
            else
              error_item = { label = "Error: Request failed", kind = 1, detail = "AI completion error: " .. err_msg }
            end
          elseif result.stdout == "" or result.stdout:match("^%s*$") then
            error_item = { label = "Error: Empty response", kind = 1, detail = "AI completion: empty response" }
          else
            local ok, data = pcall(vim.json.decode, result.stdout)
            if not ok then
              error_item = { label = "Error: Parse failed", kind = 1, detail = "AI completion: invalid JSON" }
            elseif data.error then
              error_item = { label = "Error: Server error", kind = 1, detail = "AI completion: " .. (data.error.message or data.error) }
            else
              local raw_text = data.choices and data.choices[1] and data.choices[1].text
              if raw_text and raw_text ~= "" then
                if max_lines > 1 then
                  -- Multi-line: strip markdown fences, preserve indentation
                  completion_text = raw_text:gsub("^```[%w]*\n", ""):gsub("\n```$", ""):gsub("^```", "")
                  completion_text = vim.trim(completion_text)
                else
                  -- Single-line: take text before first newline
                  local first_line = raw_text:match("^([^\n]*)") or raw_text
                  completion_text = vim.trim(first_line)
                end
              end
            end
          end

          callback(completion_text, error_item)

  -- Retry logic: no persistent error flag, each trigger calls request_completion fresh
        end)
      end
    )

    completion_queue.active_handle = handle
  end)
end

-- blink.cmp source get_completions function
local function get_completions(context, callback)
  if not config_ref.completion or not config_ref.completion.enabled then
    callback({ items = {}, is_incomplete = false })
    return
  end

  M.request_completion(context, function(completion_text, error_item)
    if error_item then
      -- Return error as a completion item so user sees it in blink.cmp
      callback({ items = { error_item }, is_incomplete = false })
      return
    end

    if not completion_text or completion_text == "" then
      callback({ items = {}, is_incomplete = false })
      return
    end

    local blink = require("blink.cmp")
    local CompletionItemKind = blink.types.CompletionItemKind

    local filetype = vim.bo[context.bufnr].filetype
    local resolved_cfg = resolve_completion_config(filetype)
    local max_lines = resolved_cfg.max_lines or 1
    local is_multi_line = max_lines > 1

    local item = {
      label = completion_text:sub(1, 80),  -- Truncate label for display
      kind = CompletionItemKind.Snippet,
      detail = is_multi_line and "AI (multi-line)" or "AI (1-line)",
      insertText = completion_text,
      insertTextFormat = 2, -- Snippet format
    }

    callback({ items = { item }, is_incomplete = false })
  end)
end

M.get_completions = get_completions

-- Export resolve_completion_config for testing/inspection
M.resolve_completion_config = resolve_completion_config

-- blink.cmp source spec (exported for blink.cmp registration)
local source_spec = {
  name = "custom_ai",
  module = "custom_ai.completion",
  opts = {
    enabled = function()
      return config_ref and config_ref.completion and config_ref.completion.enabled
    end,
  },
}

-- Export both the source spec and the get_completions function
return vim.tbl_extend("force", M, source_spec)