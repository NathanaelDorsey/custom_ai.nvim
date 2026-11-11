# Story e02s05: Single-line completion support (next token/line)

**type:** feat
**risk:** P1
**context:** domain

## Context

Implement single-line completion mode: minimal context, focus on next logical line/token. Controlled by model_config.completion.max_lines = 1. Returns blink.cmp Snippet item with single-line insertText.

## Requirements

### ADDED: model_config.completion.single_line defaults
Per-model config: max_tokens=64, temperature=0.2, stop=['\n']

### ADDED: Single-line prompt template
Minimal context, instruct model to generate only the next logical line/token.

### ADDED: Single-line response parsing
Extract text before first newline, trim whitespace.

### ADDED: blink.cmp item for single-line
kind=Snippet, insertText=single line, detail='AI (1-line)'

### ADDED: Config max_lines = 1 forces single-line mode
model_config.completion.max_lines = 1 enables single-line behavior.

## Implementation Steps

1. Add model_config.completion.single_line = { max_tokens = 64, temperature = 0.2, stop = {"\n"} } to defaults in init.lua for each model → verify: `grep -q 'single_line' lua/custom_ai/init.lua && grep -q 'max_tokens' lua/custom_ai/init.lua && grep -q 'temperature' lua/custom_ai/init.lua`

2. Create single-line prompt template in completion.lua: "Complete the next line of code. Output only the completion, no explanation." + context + prefix → verify: `grep -q 'single.line\\|single_line' lua/custom_ai/completion.lua`

3. Parse llama.cpp response: choices[0].text, split on \n, take first non-empty line, trim → verify: `grep -q '\\n' lua/custom_ai/completion.lua && grep -q 'sub\\|match\\|gmatch' lua/custom_ai/completion.lua`

4. Return blink.cmp item: kind=Snippet, insertText=single_line, detail='AI (1-line)' → verify: `grep -q 'Snippet' lua/custom_ai/completion.lua && grep -q 'single.line' lua/custom_ai/completion.lua && grep -q 'detail' lua/custom_ai/completion.lua`

5. Config: model_config.completion.max_lines = 1 forces single-line mode (check in request_completion) → verify: `grep -q 'max_lines' lua/custom_ai/init.lua && grep -q 'max_lines' lua/custom_ai/completion.lua`

6. Manual test: trigger completion in various positions (mid-line, after return, after dot), verify single-line results → verify: `echo 'MANUAL: Test single-line completions at different cursor positions'`

## Verification Script (Step-by-Step)

1. Set model_config.coder.completion.max_lines = 1
2. Open a Lua file, type: `local function calculate_sum(a, b)`
3. Press <C-space> at end of line
4. Verify completion is single line (e.g., ` return a + b end`)
5. Test at different positions: mid-expression, after `local x =`, after `return`
6. Verify no multi-line completions appear

## Out of scope

- Multi-line completions — story e02s06
- Configuration granularity — story e02s07
- Context gathering — story e02s03

## Risks

- Model may ignore stop sequence — handle in parsing by truncating at first newline
- Single-line may be too restrictive for some languages — configurable per filetype (e02s07)
- Stop sequence '\n' may not work with all models — test with configured models