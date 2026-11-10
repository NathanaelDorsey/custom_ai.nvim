# e01s05-spec.md — Config Schema Extension & Defaults

## §1 Business Narrative
The plugin needs new configuration options for vision detection: `vision_probe` to enable/disable API probing, and `vision_keywords` for filename fallback patterns. These must have sensible defaults and be documented.

## §2 User Story
As a Neovim user configuring the plugin
I want vision detection to be configurable via setup()
So that I can enable/disable API probing and customize filename patterns for my models

## §3 Acceptance Criteria
- **AC1**: `vision_probe = true` in defaults (API probe enabled by default)
- **AC2**: `vision_keywords` defaults to 6 LLaVA patterns
- **AC3**: User config merges with defaults (deep_extend preserves both)
- **AC4**: README.md documents both new options
- **AC5**: example-init.lua shows both options commented
- **AC6**: Backward compatibility: existing configs without new keys work

## §4 Requirements (Delta: ADDED)
- REQ-001: **ADDED** — `defaults.vision_probe = true`
- REQ-002: **ADDED** — `defaults.vision_keywords = {"llava", "bakllava", "llava-next", "llava-1.5", "llava-1.6", "vision"}`
- REQ-003: **ADDED** — Deep merge in `setup(opts)` handles new keys (existing behavior)
- REQ-004: **ADDED** — README.md Configuration section documents `vision_probe` and `vision_keywords`
- REQ-005: **ADDED** — example-init.lua includes commented examples of new options
- REQ-006: **ADDED** — No breaking changes: missing keys use defaults

## §5 Main Flow
1. User calls `require("custom_ai").setup({ vision_probe = false, vision_keywords = {"my-model"} })`
2. `vim.tbl_deep_extend("force", defaults, opts)` merges user config with defaults
3. New keys available in `config.vision_probe` and `config.vision_keywords`
4. Detection logic uses these values

## §6 Alternative Flows
- **AF1**: User omits new keys → defaults used
- **AF2**: User provides empty `vision_keywords = {}` → replaces defaults (deep_extend behavior for arrays)

## §7 Error Handling
- Invalid config types → handled by existing setup validation (warn, fallback to defaults)

## §8 Non-Functional
- **Documentation**: Clear examples in README and example-init.lua
- **Compatibility**: Zero breaking changes

## §9 Traceability
- Scope: `specs/product/SCOPE_LATEST.yaml` → in_scope items 7, 8
- Epic: `specs/epics/e01-vision-detection/epic.yaml` → e01s05
- Tests: `specs/tech-architecture/TEST_PLAN_LATEST.md` → scenario 10 (config validation)

## §10 Gherkin Scenarios
```gherkin
Scenario: Default config works without new keys
  Given user setup() with only server and models
  When Neovim starts
  Then vision_probe == true
  And vision_keywords contains 6 default patterns
  And no errors

Scenario: User disables API probe
  Given setup({ vision_probe = false })
  When Neovim starts with LLaVA model
  Then vision detected via filename fallback
  And warning logged about fallback

Scenario: User extends vision_keywords
  Given setup({ vision_keywords = {"custom-vision"} })
  When Neovim starts with model filename containing "custom-vision"
  Then vision detected
  And default patterns still work
```