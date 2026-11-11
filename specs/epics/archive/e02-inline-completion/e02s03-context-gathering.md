# Story e02s03: Automatic project context gathering (LSP + treesitter)

**type:** feat
**risk:** P0
**context:** domain

## Context

Gather relevant project context automatically to improve completion quality. Uses LSP (workspace symbols, references, definitions, document symbols) and treesitter (local AST queries) to find imports, type definitions, related functions, and test files. Assembles structured context for prompt injection.

## Requirements

### ADDED: Context module with gather_context(bufnr, cursor_pos)
Entry point returning structured context: imports, types, related_functions, test_files, current_scope.

### ADDED: LSP workspace symbols
Query workspace symbols matching current scope (vim.lsp.buf_request workspace/symbol).

### ADDED: LSP references/definitions
Get references and definitions for symbol under cursor (textDocument/references, textDocument/definition).

### ADDED: LSP document symbols
Get imports/dependencies via textDocument/documentSymbol.

### ADDED: Treesitter local AST
Parse current buffer, extract local functions, types, imports near cursor using vim.treesitter queries.

### ADDED: Test file discovery
Find test files for current file (conventions: *_test, test_*, spec_* in same dir or test/).

### ADDED: Context assembly
Structured prompt sections: imports, types, related_fns, tests, current_scope with token budgeting.

### ADDED: Context config
config.context = { max_tokens = 2000, include_imports = true, include_types = true, include_tests = true, max_related_files = 3 }

## Implementation Steps

1. Create `lua/custom_ai/context.lua` with `gather_context(bufnr, cursor_pos)` entry point returning structured table → verify: `test -f lua/custom_ai/context.lua && grep -q 'gather_context' lua/custom_ai/context.lua`

2. LSP: workspace/symbol request for symbols in current namespace/package → verify: `grep -q 'workspace/symbol' lua/custom_ai/context.lua`

3. LSP: textDocument/references for symbol under cursor (if any) → verify: `grep -q 'textDocument/references' lua/custom_ai/context.lua`

4. LSP: textDocument/definition for symbol under cursor → verify: `grep -q 'textDocument/definition' lua/custom_ai/context.lua`

5. LSP: textDocument/documentSymbol for current buffer to extract imports/type defs → verify: `grep -q 'documentSymbol' lua/custom_ai/context.lua`

6. Treesitter: get parser for buffer, run queries for local functions, types, imports near cursor → verify: `grep -q 'vim.treesitter' lua/custom_ai/context.lua && grep -q 'query' lua/custom_ai/context.lua`

7. Find test files: check same directory for *_test.*, test_*.*, spec_*.* and test/ directory → verify: `grep -q 'test' lua/custom_ai/context.lua && grep -q 'spec' lua/custom_ai/context.lua`

8. Assemble context: deduplicate, rank by relevance, truncate to config.context.max_tokens → verify: `grep -q 'imports\\|types\\|related_fns\\|tests' lua/custom_ai/context.lua && grep -q 'max_tokens' lua/custom_ai/context.lua`

9. Add context config to init.lua defaults → verify: `grep -q 'context' lua/custom_ai/init.lua && grep -q 'max_tokens' lua/custom_ai/init.lua && grep -q 'include_imports' lua/custom_ai/init.lua`

10. Manual test: open multi-file project with LSP, trigger completion, inspect prompt sent to server (add debug log) → verify: `echo 'MANUAL: Open multi-file project, trigger completion, inspect prompt sent to server'`

## Verification Script (Step-by-Step)

1. Open a multi-file Lua/Python project with LSP active (lua_ls, pyright)
2. In a file that imports from other files, position cursor after a function call
3. Trigger completion (or call gather_context directly via `:lua print(vim.inspect(require("custom_ai.context").gather_context(0, vim.api.nvim_win_get_cursor(0))))`)
4. Verify returned context includes: imports from other files, type definitions, related functions
5. Verify test files found if they exist
6. Verify token count respects max_tokens config

## Out of scope

- Cross-file completion awareness beyond context gathering — story e02s03 covers context only
- Completion request sending — story e02s04
- Prompt template engineering — story e02s05/e02s06

## Risks

- LSP may not be attached/ready — handle gracefully with timeouts and fallbacks
- Large projects: workspace/symbol can be slow — limit results, add timeout
- Treesitter queries language-specific — need queries for each supported filetype
- Token budgeting: context may exceed model context window — truncate intelligently