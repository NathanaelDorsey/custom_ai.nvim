-- custom_ai.nvim — Project context gathering for AI completions
-- Gathers relevant context via LSP and treesitter to improve completion quality

local M = {}

local config_ref = nil

function M.set_config(cfg)
  config_ref = cfg
end

-- Main entry point: gather context for completion at cursor position
-- Returns structured table: { imports, types, related_fns, tests, current_scope }
-- @param bufnr number: buffer number
-- @param cursor_pos table: { line (1-indexed), col (0-indexed) }
-- @param callback function: called with context table
function M.gather_context(bufnr, cursor_pos, callback)
  local ctx = {
    imports = {},
    types = {},
    related_fns = {},
    tests = {},
    current_scope = "",
  }

  -- If no LSP client attached, fall back to treesitter only
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    M._gather_treesitter_context(bufnr, cursor_pos, ctx, callback)
    return
  end

  local client = clients[1]
  local pending = 0
  local function done()
    pending = pending - 1
    if pending <= 0 then
      M._assemble_and_truncate(ctx, callback)
    end
  end

  -- 1. Get document symbols (imports, type definitions, functions)
  pending = pending + 1
  M._get_document_symbols(client, bufnr, ctx, done)

  -- 2. Get symbol under cursor, then references and definitions
  local symbol = M._get_symbol_at_cursor(bufnr, cursor_pos)
  if symbol then
    ctx.current_scope = symbol.name

    -- References
    pending = pending + 1
    M._get_references(client, bufnr, cursor_pos, symbol, ctx, done)

    -- Definitions
    pending = pending + 1
    M._get_definitions(client, bufnr, cursor_pos, symbol, ctx, done)
  end

  -- 3. Workspace symbols for current namespace/package
  pending = pending + 1
  M._get_workspace_symbols(client, ctx, done)

  -- 4. Treesitter context (always run)
  pending = pending + 1
  M._gather_treesitter_context(bufnr, cursor_pos, ctx, done)

  -- 5. Find test files
  pending = pending + 1
  M._find_test_files(bufnr, ctx, done)
end

-- Get LSP document symbols for current buffer
function M._get_document_symbols(client, bufnr, ctx, callback)
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  client.request("textDocument/documentSymbol", params, function(err, result)
    if err or not result then
      callback(ctx)
      return
    end

    local function extract_symbols(symbols, prefix)
      for _, sym in ipairs(symbols) do
        local name = sym.name
        local kind = sym.kind
        local full_name = prefix .. name

        -- Kind 9 = Module, 10 = Namespace, 11 = Package (imports)
        -- Kind 5 = Class, 6 = Interface, 23 = TypeParameter, 24 = Type
        -- Kind 12 = Method, 6 = Function, 13 = Property
        if kind == 9 or kind == 10 or kind == 11 then
          table.insert(ctx.imports, full_name)
        elseif kind == 5 or kind == 6 or kind == 23 or kind == 24 then
          table.insert(ctx.types, full_name)
        elseif kind == 12 or kind == 6 or kind == 13 then
          table.insert(ctx.related_fns, full_name)
        end

        -- Recurse into children
        if sym.children then
          extract_symbols(sym.children, full_name .. ".")
        end
      end
    end

    extract_symbols(result, "")
    callback(ctx)
  end)
end

-- Get symbol at cursor position
function M._get_symbol_at_cursor(bufnr, cursor_pos)
  local line = cursor_pos[1] - 1  -- 0-indexed
  local col = cursor_pos[2]
  local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""

  -- Simple heuristic: find word at cursor
  local before = line_text:sub(1, col)
  local after = line_text:sub(col + 1)
  local word = before:match("([%w_%.]+)$") or ""
  word = word .. (after:match("^([%w_%.]*)") or "")

  if word ~= "" then
    return { name = word, line = line, col = col }
  end
  return nil
end

-- Get references for symbol under cursor
function M._get_references(client, bufnr, cursor_pos, symbol, ctx, callback)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = cursor_pos[1] - 1, character = cursor_pos[2] },
    context = { includeDeclaration = true },
  }
  client.request("textDocument/references", params, function(err, result)
    if err or not result then
      callback(ctx)
      return
    end

    -- Collect unique files that reference this symbol
    local files = {}
    for _, ref in ipairs(result) do
      local uri = ref.uri or ref.targetUri
      if uri then
        local filepath = vim.uri_to_fname(uri)
        if filepath and not files[filepath] then
          files[filepath] = true
          table.insert(ctx.related_fns, "ref:" .. vim.fn.fnamemodify(filepath, ":t"))
        end
      end
    end
    callback(ctx)
  end)
end

-- Get definitions for symbol under cursor
function M._get_definitions(client, bufnr, cursor_pos, symbol, ctx, callback)
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    position = { line = cursor_pos[1] - 1, character = cursor_pos[2] },
  }
  client.request("textDocument/definition", params, function(err, result)
    if err or not result then
      callback(ctx)
      return
    end

    local locations = vim.islist(result) and result or { result }
    for _, loc in ipairs(locations) do
      local uri = loc.uri or loc.targetUri
      if uri then
        local filepath = vim.uri_to_fname(uri)
        if filepath then
          table.insert(ctx.types, "def:" .. vim.fn.fnamemodify(filepath, ":t"))
        end
      end
    end
    callback(ctx)
  end)
end

-- Get workspace symbols for current namespace/package
function M._get_workspace_symbols(client, ctx, callback)
  -- Query with empty string to get all, or use current scope
  local query = ctx.current_scope ~= "" and ctx.current_scope or ""
  local params = { query = query }
  client.request("workspace/symbol", params, function(err, result)
    if err or not result then
      callback(ctx)
      return
    end

    for _, sym in ipairs(result) do
      if sym.kind == 5 or sym.kind == 6 or sym.kind == 23 or sym.kind == 24 then
        table.insert(ctx.types, sym.name)
      elseif sym.kind == 12 or sym.kind == 6 then
        table.insert(ctx.related_fns, sym.name)
      end
    end
    callback(ctx)
  end, 2000)  -- 2 second timeout
end

-- Gather context using treesitter
function M._gather_treesitter_context(bufnr, cursor_pos, ctx, callback)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    callback(ctx)
    return
  end

  parser:parse(true, function(_, trees)
    if not trees or #trees == 0 then
      callback(ctx)
      return
    end

    local tree = trees[1]
    local root = tree:root()
    local lang = parser:lang()

    -- Define queries for different languages
    local queries = M._get_treesitter_queries(lang)
    if not queries then
      callback(ctx)
      return
    end

    for _, query_def in ipairs(queries) do
      local query = vim.treesitter.query.parse(lang, query_def.query)
      for id, node in query:iter_captures(root, bufnr) do
        local capture_name = query.captures[id]
        local text = vim.treesitter.get_node_text(node, bufnr)

        if capture_name == "import" then
          table.insert(ctx.imports, text)
        elseif capture_name == "type" then
          table.insert(ctx.types, text)
        elseif capture_name == "function" then
          table.insert(ctx.related_fns, text)
        end
      end
    end

    callback(ctx)
  end)
end

-- Get treesitter queries for supported languages
function M._get_treesitter_queries(lang)
  local queries = {
    lua = {
      query = [[
        (require_statement (string) @import)
        (function_declaration name: (identifier) @function)
        (local_function name: (identifier) @function)
        (type_declaration name: (identifier) @type)
      ]],
    },
    python = {
      query = [[
        (import_statement (dotted_name) @import)
        (import_from_statement (dotted_name) @import)
        (class_definition name: (identifier) @type)
        (function_definition name: (identifier) @function)
      ]],
    },
    javascript = {
      query = [[
        (import_statement (string) @import)
        (import_clause (identifier) @import)
        (class_declaration name: (identifier) @type)
        (function_declaration name: (identifier) @function)
        (arrow_function) @function
      ]],
    },
    typescript = {
      query = [[
        (import_statement (string) @import)
        (import_clause (identifier) @import)
        (class_declaration name: (identifier) @type)
        (interface_declaration name: (identifier) @type)
        (type_alias_declaration name: (identifier) @type)
        (function_declaration name: (identifier) @function)
        (arrow_function) @function
      ]],
    },
    go = {
      query = [[
        (import_spec (string) @import)
        (import_spec (identifier) @import)
        (type_declaration (type_spec name: (identifier) @type))
        (function_declaration name: (identifier) @function)
        (method_declaration name: (identifier) @function)
      ]],
    },
    rust = {
      query = [[
        (use_declaration (use_tree) @import)
        (struct_item name: (type_identifier) @type)
        (enum_item name: (type_identifier) @type)
        (trait_item name: (type_identifier) @type)
        (function_item name: (identifier) @function)
      ]],
    },
  }
  return queries[lang]
end

-- Find test files for current buffer
function M._find_test_files(bufnr, ctx, callback)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then
    callback(ctx)
    return
  end

  local dir = vim.fn.fnamemodify(filepath, ":h")
  local basename = vim.fn.fnamemodify(filepath, ":t:r")
  local ext = vim.fn.fnamemodify(filepath, ":e")

  local test_patterns = {
    dir .. "/*_test." .. ext,
    dir .. "/test_*." .. ext,
    dir .. "/spec_*." .. ext,
    dir .. "/test/*. " .. ext,
    dir .. "/tests/*. " .. ext,
    dir .. "/spec/*. " .. ext,
    dir .. "/../test/*" .. basename .. "*." .. ext,
    dir .. "/../tests/*" .. basename .. "*." .. ext,
  }

  local found = {}
  for _, pattern in ipairs(test_patterns) do
    local matches = vim.fn.glob(pattern, false, true)
    for _, match in ipairs(matches) do
      if vim.fn.filereadable(match) == 1 and not found[match] then
        found[match] = true
        table.insert(ctx.tests, vim.fn.fnamemodify(match, ":t"))
      end
    end
  end

  callback(ctx)
end

-- Assemble and truncate context to token budget
function M._assemble_and_truncate(ctx, callback)
  local config = config_ref or {}
  local context_cfg = config.context or {}
  local max_tokens = context_cfg.max_tokens or 2000
  local include_imports = context_cfg.include_imports ~= false
  local include_types = context_cfg.include_types ~= false
  local include_tests = context_cfg.include_tests ~= false
  local max_related = context_cfg.max_related_files or 3

  -- Deduplicate
  ctx.imports = M._deduplicate(ctx.imports)
  ctx.types = M._deduplicate(ctx.types)
  ctx.related_fns = M._deduplicate(ctx.related_fns)
  ctx.tests = M._deduplicate(ctx.tests)

  -- Limit related_fns to max_related
  if #ctx.related_fns > max_related then
    ctx.related_fns = { unpack(ctx.related_fns, 1, max_related) }
  end

  -- Build context string and estimate tokens (rough: 1 token ≈ 4 chars)
  local parts = {}
  if include_imports and #ctx.imports > 0 then
    table.insert(parts, "IMPORTS:\n" .. table.concat(ctx.imports, "\n"))
  end
  if include_types and #ctx.types > 0 then
    table.insert(parts, "TYPES:\n" .. table.concat(ctx.types, "\n"))
  end
  if #ctx.related_fns > 0 then
    table.insert(parts, "RELATED_FNS:\n" .. table.concat(ctx.related_fns, "\n"))
  end
  if include_tests and #ctx.tests > 0 then
    table.insert(parts, "TESTS:\n" .. table.concat(ctx.tests, "\n"))
  end

  local context_str = table.concat(parts, "\n\n")
  local estimated_tokens = #context_str / 4

  -- Truncate if over budget
  if estimated_tokens > max_tokens then
    local max_chars = max_tokens * 4
    context_str = context_str:sub(1, max_chars) .. "\n... (truncated)"
  end

  ctx._full = context_str
  callback(ctx)
end

-- Deduplicate array
function M._deduplicate(arr)
  local seen = {}
  local result = {}
  for _, v in ipairs(arr) do
    if not seen[v] then
      seen[v] = true
      table.insert(result, v)
    end
  end
  return result
end

return M