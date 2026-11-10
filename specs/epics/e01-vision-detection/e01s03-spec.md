# e01s03-spec.md — Filename Pattern Fallback

## §1 Business Narrative
Vision capability detection checks the llama.cpp API **first** (via a minimal probe request with `image_url` content part), and falls back to detecting from the model **filename** using configurable keyword patterns when the API probe is disabled or fails.

## §2 User Story
As a Neovim user with custom or unnamed vision models
I want vision detection to work via filename patterns when API probe fails
So that vision features work even for models not recognized by the API probe

## §3 Acceptance Criteria
- **AC1**: `config.vision_probe = false` → vision detected via filename patterns
- **AC2**: API probe timeout/failure → falls back to filename patterns, logs warning
- **AC3**: Default `vision_keywords` covers LLaVA variants: llava, bakllava, llava-next, llava-1.5, llava-1.6, vision
- **AC4**: User can extend `vision_keywords` in config for custom model names
- **AC5**: Fallback logs warning at WARN level

## §4 Requirements (Delta: ADDED)
- REQ-001: **ADDED** — `detect_vision_capability()` checks `config.vision_probe`; when true, **attempts API probe first**
- REQ-002: **ADDED** — API probe success (`200 OK`, no error body) → return `true` immediately
- REQ-003: **ADDED** — API probe failure/timeout → log WARN, **fall back to** `detect_vision_from_filename()`
- REQ-004: **ADDED** — `config.vision_probe == false` → skip probe entirely, use filename detection directly
- REQ-005: **ADDED** — `detect_vision_from_filename()` matches detected model filename against `config.vision_keywords` (case-insensitive substring)
- REQ-006: **ADDED** — Default `vision_keywords` includes 6 LLaVA-related patterns
- REQ-007: **ADDED** — User config `vision_keywords` merges with defaults via `tbl_deep_extend`
- REQ-008: **ADDED** — Filename fallback logs "Using filename fallback for vision detection" at WARN level

## §5 Main Flow
1. `detect_vision_capability()` called
2. **Step 1 — API probe (first):** If `config.vision_probe == true`:
   - Send minimal chat request with dummy `image_url` to `/v1/chat/completions` (500ms timeout)
   - On success (200 OK, no error) → set `state.detected_vision = true`, return `true`
   - On failure/timeout/network error → log WARN, proceed to Step 2
3. **Step 2 — Filename fallback (second):** If probe was disabled (`vision_probe == false`) or probe failed:
   - Call `detect_vision_from_filename()`
   - Get detected model filename from `state.detected_model` or `/v1/models`
   - Strip path and `.gguf` extension
   - Check if any keyword in `config.vision_keywords` matches filename (case-insensitive substring)
   - Return `true` if any match, `false` otherwise

## §6 Alternative Flows
- **AF1**: No model detected → return false
- **AF2**: Filename empty → return false

## §7 Error Handling
- Probe network error → warn → filename fallback
- Probe timeout → warn → filename fallback
- Probe 400/500 → filename fallback (no extra warn, already logged in probe)
- JSON decode error in probe → warn → filename fallback

## §8 Non-Functional
- **Performance**: Filename detection is instant (no network)
- **Configurability**: User extends patterns without code changes

## §9 Traceability
- Scope: `specs/product/SCOPE_LATEST.yaml` → in_scope items 3, 4, 7
- Epic: `specs/epics/e01-vision-detection/epic.yaml` → e01s03
- Tests: `specs/tech-architecture/TEST_PLAN_LATEST.md` → scenarios 1, 2, 10

## §10 Configuration
```lua
defaults = {
  vision_probe = true,
  vision_keywords = {"llava", "bakllava", "llava-next", "llava-1.5", "llava-1.6", "vision"},
}
-- User config merges: vision_keywords = {"my-custom-vision"} adds to defaults
```

## §11 Gherkin Scenarios
```gherkin
Scenario: Filename fallback when probe disabled
  Given vision_probe = false
  And llama.cpp server running with LLaVA model
  When Neovim starts
  Then state.detected_vision == true
  And warning logged "Using filename fallback for vision detection"

Scenario: Custom model name in vision_keywords
  Given vision_keywords = {"my-custom-vision"}
  And llama.cpp server running with model filename containing "my-custom-vision"
  When Neovim starts
  Then state.detected_vision == true

Scenario: API probe fails → filename fallback
  Given vision_probe = true
  And llama.cpp server returns 400 for vision probe
  When Neovim starts
  Then state.detected_vision determined by filename
  And warning logged about fallback
```