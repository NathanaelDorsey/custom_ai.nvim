# Story e02s06: Multi-line block completion support (functions, control structures)

**type:** feat
**risk:** P1
**context:** domain

## Context

Implement multi-line completion mode: richer context, generate complete blocks (functions, classes, control structures) with proper indentation. Controlled by model_config.completion.max_lines > 1 (or = 0 for unlimited). Returns blink.cmp Snippet item with multi-line insertText and $0 placeholder.

## Requirements

### ADDED: model_config.completion.multi_line defaults
Per-model config: max_tokens=512, temperature=0.3, stop=['```', 'function', 'class']

### ADDED: Multi-line prompt template
Richer context, instruct model to generate complete block with proper indentation.

### ADDED: Multi-line response parsing
Preserve indentation, handle markdown code blocks (strip ```), detect language.

### ADDED: blink.cmp item for multi-line
kind=Snippet, insertText=multi-line with $0 placeholder, detail='AI (multi-line)'

### ADDED: Config max_lines > 1 enables multi-line mode
model_config.completion.max_lines > 1 (or = 0) enables multi-line behavior.

### ADDED: Smart detection
If cursor at function/class start → multi-line, else single-line (configurable).

## Implementation Steps

1. Add model_config.completion.multi_line = { max_tokens = 512, temperature = 0.3, stop = {"```", "function", "class"} } to defaults in init.lua → verify: `grep -q 'multi_line' lua/custom_ai/init.lua && grep -q 'max_tokens' lua/custom_ai/init.lua && grep -q 'stop' lua/custom_ai/init.lua`

2. Create multi-line prompt template in completion.lua: "Generate a complete code block. Use proper indentation. Output only the code." + context + prefix → verify: `grep -q 'multi.line\\|multi_line' lua/custom_ai/completion.lua`

3. Parse multi-line response: strip markdown ``` fences, preserve indentation, detect if snippet placeholder needed → verify: `grep -q 'indentation\\|gsub\\|```' lua/custom_ai/completion.lua`

4. Return blink.cmp item: kind=Snippet, insertText=multi_line_with_$0, detail='AI (multi-line)' → verify: `grep -q 'insertText' lua/custom_ai/completion.lua && grep -q '\\$0' lua/custom_ai/completion.lua && grep -q 'multi.line' lua/custom_ai/completion.lua`

5. Config: model_config.completion.max_lines > 1 (or = 0 for unlimited) enables multi-line mode → verify: `grep -q 'max_lines' lua/custom_ai/init.lua && grep -q 'max_lines' lua/custom_ai/completion.lua`

6. Smart detection: check cursor context (function/class/control structure start) → auto-select mode → verify: `grep -q 'function\\|class\\|if\\|for\\|while' lua/custom_ai/completion.lua`

7. Manual test: trigger at function definition, class, if/for/while, verify multi-line block generated → verify: `echo 'MANUAL: Test multi-line at function start, class, control structures'`

## Verification Script (Step-by-Step)

1. Set model_config.coder.completion.max_lines = 10
2. Open a Lua file, type: `local function fibonacci(n)`
3. Press <C-space> at end of line
4. Verify completion is multi-line (e.g., full function body with proper indentation)
5. Test at class definition (if language supports), if statement, for loop
6. Verify $0 placeholder at end for cursor positioning
7. Test smart detection: type `if true then` press <C-space>, verify block completion

## Out of scope

- Single-line completions — story e02s05
- Configuration granularity — story e02s07
- Context gathering — story e02s03

## Risks

- Model may not generate proper indentation — handle in parsing by normalizing indentation
- Stop sequences may not work reliably — fallback to max_tokens limit
- Large multi-line completions may exceed context window — context truncation in e02s03
- Snippet placeholder $0 may not work in all blink.cmp versions — test