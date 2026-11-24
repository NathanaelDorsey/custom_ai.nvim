-- Model definitions: key -> human-readable name
-- Used for auto-detection matching and display
-- Edit this file to add/remove models without touching init.lua

return {
  allrounder = "Nemotron-Bolt-E4B Q5_K (allrounder: 65K, reasoning, tools)",
  coder      = "Qwen3 8B Q4 (coder: 24K, reasoning, tools)",
  specialist = "Qwen2.5-Coder 7B Q6_K Instruct (specialist: 32K native, best code)",
  efficient  = "Qwen3.5 4B Q8 (efficient: 16K, reasoning, tools)",
  vision     = "LLaVA-NeXT-8B Q6_K (vision: 4K, multimodal, OCR)",
  -- Define your custom models in ~/.config/nvim/lua/custom_ai_config.lua
}