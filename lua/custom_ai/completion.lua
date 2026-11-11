-- custom_ai.nvim — blink.cmp completion source
-- Provides AI-powered completions via llama.cpp /v1/completions

local M = {}

local config_ref = nil
local state_ref = nil
local context_module = nil

function M.set_refs(cfg, st)
  config_ref = cfg
  state_ref = st
  context_module = require("custom_ai.context")
  context_module.set_config(cfg)
end

-- Build the prompt for completion with project context
local function build_prompt(context, project_ctx)
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

  -- Determine if multi-line or single-line based on config
  local model_cfg = config_ref.model_config and config_ref.model_config[state_ref.current_model_key] or {}
  local completion_cfg = model_cfg.completion or {}
  local max_lines = completion_cfg.max_lines or 1
  local is_multi_line = max_lines > 1

  local system_instruction
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
-- callback: function(completion_text) called with the parsed completion
function M.request_completion(context, callback)
  -- Gather project context first
  local bufnr = context.bufnr
  local cursor_pos = context.cursor

  context_module.gather_context(bufnr, cursor_pos, function(project_ctx)
    local prompt = build_prompt(context, project_ctx)

    local model_cfg = config_ref.model_config and config_ref.model_config[state_ref.current_model_key] or {}
    local completion_cfg = model_cfg.completion or {}
    local temperature = completion_cfg.temperature or model_cfg.temperature or config_ref.temperature
    local max_tokens = completion_cfg.max_tokens or (max_lines > 1 and 512 or 64)
    local top_p = completion_cfg.top_p or model_cfg.top_p or config_ref.top_p
    local stop_sequences = completion_cfg.stop_sequences or { "\n" }

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
      callback(nil)
      return
    end
    f:write(json)
    f:close()

    local completions_url = string.format("http://%s:%d/v1/completions", config_ref.server.host, config_ref.server.port)

    vim.system(
      { "curl", "-s", "-X", "POST", completions_url, "-H", "Content-Type: application/json", "-d", "@" .. tmp_file },
      { text = true },
      function(result)
        vim.schedule(function()
          os.remove(tmp_file)

          local completion_text = nil
          if result.code ~= 0 then
            vim.notify("custom_ai.nvim: Completion request failed (curl error): " .. (result.stderr or "unknown"), vim.log.levels.WARN)
          elseif result.stdout == "" or result.stdout:match("^%s*$") then
            vim.notify("custom_ai.nvim: Completion request failed: empty response", vim.log.levels.WARN)
          else
            local ok, data = pcall(vim.json.decode, result.stdout)
            if not ok then
              vim.notify("custom_ai.nvim: Completion response parse error: " .. result.stdout:sub(1, 200), vim.log.levels.WARN)
            elseif data.error then
              vim.notify("custom_ai.nvim: Completion server error: " .. (data.error.message or data.error), vim.log.levels.WARN)
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

          callback(completion_text)
        end)
      end
    )
  end)
end

-- blink.cmp source get_completions function
local function get_completions(context, callback)
  if not config_ref.completion or not config_ref.completion.enabled then
    callback({ items = {}, is_incomplete = false })
    return
  end

  M.request_completion(context, function(completion_text)
    if not completion_text or completion_text == "" then
      callback({ items = {}, is_incomplete = false })
      return
    end

    local blink = require("blink.cmp")
    local CompletionItemKind = blink.types.CompletionItemKind

    local model_cfg = config_ref.model_config and config_ref.model_config[state_ref.current_model_key] or {}
    local completion_cfg = model_cfg.completion or {}
    local max_lines = completion_cfg.max_lines or 1
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