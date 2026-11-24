-- Startup scripts: key -> shell command
-- Run in terminal to start llama.cpp server for each model
-- Paths are relative to home directory (~)

return {
  allrounder = "llama/scripts/llm-NEMOTRON-allrounder-reasoning-tools-65k.sh",
  coder      = "llama/scripts/llm-QWEN3-8B-coder-reasoning-tools-24k.sh",
  specialist = "llama/scripts/llm-QWEN2.5-CODER-7B-specialist-32k.sh",
  efficient  = "llama/scripts/llm-QWEN3.5-4B-efficient-reasoning-tools-16k.sh",
  vision     = "llama/scripts/llm-llava-next-8b-vision.sh",
  -- Define your custom models in ~/.config/nvim/lua/custom_ai_config.lua
}