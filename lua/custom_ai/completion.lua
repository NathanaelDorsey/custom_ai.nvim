-- custom_ai.nvim — blink.cmp completion source
-- Provides AI-powered single-line completions via llama.cpp /v1/completions

local M = {}

local config_ref = nil
local state_ref = nil

function M.set_refs(cfg, st)
  config_ref = cfg
  state_ref = st
end

-- Build the prompt for single-line completion
-- system instruction + file prefix (5 lines before cursor) + cursor line
local function build_prompt(context)
  local buf = context.bufnr
  local cursor = context.cursor
  local line = cursor[1]  -- 1-indexed line number
  local col = cursor[2]   -- 0-indexed column

  -- Get 5 lines before cursor line (or fewer if at top of file)
  local start_line = math.max(1, line - 5)
  local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, line - 1, false)
  local prefix = table.concat(lines, "\n")

  -- Get current line up to cursor
  local current_line = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
  local cursor_line_prefix = current_line:sub(1, col)

  local filetype = vim.bo[buf].filetype
  local filename = vim.api.nvim_buf_get_name(buf)
  filename = filename ~= "" and vim.fn.fnamemodify(filename, ":t") or "unknown"

  local system_instruction = string.format(
    "You are a code completion engine. Complete the current line with a single line of %s code.\n" ..
    "Return ONLY the completion text, no explanations, no markdown, no extra lines.",
    filetype
  )

  local prompt = string.format(
    "%s\n\nFile: %s\n\n%s%s",
    system_instruction,
    filename,
    prefix,
    cursor_line_prefix
  )

  return prompt
end

-- Request completion from llama.cpp /v1/completions endpoint
-- context: blink.cmp context (bufnr, cursor, etc.)
-- callback: function(completion_text) called with the parsed single-line completion
function M.request_completion(context, callback)
  local prompt = build_prompt(context)

  local model_cfg = config_ref.model_config and config_ref.model_config[state_ref.current_model_key] or {}
  local temperature = model_cfg.temperature or config_ref.temperature
  local max_tokens = 64  -- Single line only
  local top_p = model_cfg.top_p or config_ref.top_p

  local json = vim.json.encode({
    model = config_ref.default_model,
    prompt = prompt,
    stream = false,
    temperature = temperature,
    max_tokens = max_tokens,
    top_p = top_p,
    stop = { "\n" },  -- Stop at first newline
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
            -- Extract choices[0].text, take text before first \n, trim
            local raw_text = data.choices and data.choices[1] and data.choices[1].text
            if raw_text and raw_text ~= "" then
              -- Take text before first newline
              local first_line = raw_text:match("^([^\n]*)") or raw_text
              completion_text = vim.trim(first_line)
            end
          end
        end

        callback(completion_text)
      end)
    end
  )
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

    local item = {
      label = completion_text,
      kind = CompletionItemKind.Snippet,
      detail = "AI (1-line)",
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