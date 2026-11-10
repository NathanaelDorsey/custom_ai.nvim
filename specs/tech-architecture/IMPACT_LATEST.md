# IMPACT_LATEST.md — Impact Analysis for custom_ai.nvim

## Change Impact Matrix

| Change Area | Affected Components | Risk | Migration |
|-------------|---------------------|------|-----------|
| `setup()` config schema | All features | Medium | Deep merge preserves unknown keys |
| Keymap defaults | Chat window only | Low | User overrides via config |
| Model detection logic | `switch_model`, `refresh_model`, startup | Medium | Fallback to first config key |
| Server script execution | `switch_model`, `start_server` | High | User scripts unchanged |
| HTTP payload format | `send_prompt`, vision, edit, test | Medium | OpenAI-compatible, stable |
| Chat buffer/window | `chat`, `new_chat`, toggle | Low | Internal implementation |
| Queue processing | All async features | Medium | Sequential order preserved |

## Breaking Change Policy
- **Never** break `setup(opts)` signature
- **Never** remove public functions without deprecation cycle
- **Never** change keymap defaults without major version
- Config additions: additive only (new keys optional)

## Dependency Impact
- Zero Lua dependencies → no supply chain risk
- `curl`, `bash`, `pkill`, `pgrep` — standard on Linux/macOS
- Windows: requires WSL or Git Bash for scripts

## Upgrade Path
- Manual copy: replace `init.lua`, re-run `setup()`
- lazy.nvim: update commit hash, Neovim reload
- Config: forward-compatible (unknown keys ignored)