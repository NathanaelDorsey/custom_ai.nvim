# Inline Code Completion Feature — Clarifying Questions

This document captures key design decisions for adding **togglable inline code completion** (Copilot-style) to `custom_ai.nvim`.

Please answer each question by adding your response below the question. Use plannotator to annotate.

---

## 1. Trigger Mechanism

**How should inline completions be triggered?**

- [ ] **A) Automatic "ghost text"** — suggestions appear automatically as you type (like Copilot), accept with `Tab`
- [ ] **B) Manual keybinding** — press a key (e.g., `<C-space>`) to request completion at cursor
- [ ] **C) Both** — automatic with manual override keybinding
- [ ] **D) Other** — describe: _________________________________________

**Your answer:**

---

## 2. Project Context Scope

**What does "scan the project for context" mean?**

- [ ] **A) Automatic relevance** — plugin automatically finds/includes relevant files (imports, types, related functions, test files) using LSP/treesitter
- [ ] **B) Current file + open buffers only**
- [ ] **C) User-selected files** — picker UI (telescope/fzf-lua) to choose context files
- [ ] **D) Current file + workspace symbols** — via LSP workspace symbols
- [ ] **E) Other** — describe: _________________________________________

**Your answer:**

---

## 3. Completion Granularity

**What scope of completions?**

- [ ] **A) Single-line** — next logical line/token (Copilot's default)
- [ ] **B) Multi-line blocks** — entire functions, control structures, etc.
- [ ] **C) Both, configurable** — user chooses per-model or per-project
- [ ] **D) Other** — describe: _________________________________________

**Your answer:**

---

## 4. Performance Target

**What latency is acceptable for local llama.cpp?**

- [ ] **A) <100ms** — needs streaming/prefill, may require model quantization trade-offs
- [ ] **B) <300ms** — comfortable for local 7B-8B models on modern hardware
- [ ] **C) <500ms** — acceptable, no special optimization needed
- [ ] **D) No hard target** — "usable" is enough
- [ ] **E) Other** — describe: _________________________________________

**Your answer:**

---

## 5. Neovim Completion Integration

**How should completions surface in Neovim?**

- [ ] **A) nvim-cmp source** — integrate as a completion source (works with existing cmp setup)
- [ ] **B) blink.cmp source** — modern alternative to nvim-cmp
- [ ] **C) Native LSP completion** — `vim.lsp.completion` (Neovim 0.11+)
- [ ] **D) Standalone virtual text** — custom floating ghost text, no completion menu
- [ ] **E) Both virtual text + completion menu** — ghost text inline + `<C-n>`/`<C-p>` menu
- [ ] **F) Not sure** — need recommendation based on architecture

**Your answer:**

---

## 6. Toggle Behavior

**How should "togglable" work?**

- [ ] **A) Global on/off** — single keymap/command enables/disables everywhere
- [ ] **B) Per-buffer** — enable/disable per filetype or buffer
- [ ] **C) Per-project** — config-driven (`.nvim/custom_ai.json` or similar)
- [ ] **D) Context-aware** — auto-disable in comments, strings, certain filetypes
- [ ] **E) All of the above** — layered toggles

**Your answer:**

---

## 7. Model Selection for Completion

**Which model(s) should power completions?**

- [ ] **A) Dedicated "fast" model** — separate small model (e.g., 1.5B-3B) for speed
- [ ] **B) Current active model** — whatever model is loaded (coder/specialist/etc.)
- [ ] **C) Configurable per filetype** — different models for different languages
- [ ] **D) User chooses at toggle-time** — picker to select completion model

**Your answer:**

---

## 8. Streaming vs. Blocking

**Should completions stream token-by-token or wait for full response?**

- [ ] **A) Streaming** — show partial completion as tokens arrive (lower perceived latency)
- [ ] **B) Blocking** — wait for full completion, then show (simpler implementation)
- [ ] **C) Hybrid** — stream for short completions, block for long ones

**Your answer:**

---

## 9. Accept/Reject/Dismiss UX

**How does the user interact with shown completions?**

- [ ] **A) Tab to accept, Esc to dismiss** — standard Copilot behavior
- [ ] **B) Tab accepts, Ctrl+] cycles alternatives** — if multiple completions generated
- [ ] **C) Inline preview** — show completion as virtual text, accept with key
- [ ] **D) Completion menu** — show in nvim-cmp/blink menu alongside LSP

**Your answer:**

---

## 10. Out of Scope (Confirm)

**Explicitly NOT in this feature:**

- [ ] Chat window integration (separate feature)
- [ ] Multi-file edits / refactoring
- [ ] Test generation
- [ ] Documentation generation
- [ ] Other: _________________________________________

**Your answer:**

---

## Summary

After you answer, I'll synthesize into `specs/planning-context.yaml` and recommend the next skill (`scope-work` → `slice-tasks` → `plan-work`).