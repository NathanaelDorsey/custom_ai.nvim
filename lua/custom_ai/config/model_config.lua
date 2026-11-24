-- Per-model generation parameters
-- Keys must match those in models.lua
-- Override any subset; unspecified fields fall back to global defaults

return {
  allrounder = {
    temperature = 0.7,
    top_p = 0.8,
    max_tokens = 4096,
    completion = {
      max_lines = 1,
      temperature = 0.2,
      top_p = 0.8,
      max_tokens = 64,
      stop_sequences = { "\n" },
      prompt_template = nil,
    },
  },
  coder = {
    temperature = 0.3,
    top_p = 0.9,
    max_tokens = 8192,
    completion = {
      max_lines = 10,
      temperature = 0.2,
      top_p = 0.9,
      max_tokens = 256,
      stop_sequences = { "\n" },
      prompt_template = nil,
    },
  },
  specialist = {
    temperature = 0.2,
    top_p = 0.95,
    max_tokens = 8192,
    completion = {
      max_lines = 20,
      temperature = 0.2,
      top_p = 0.95,
      max_tokens = 512,
      stop_sequences = { "\n" },
      prompt_template = nil,
    },
  },
  efficient = {
    temperature = 0.5,
    top_p = 0.9,
    max_tokens = 2048,
    completion = {
      max_lines = 5,
      temperature = 0.2,
      top_p = 0.9,
      max_tokens = 128,
      stop_sequences = { "\n" },
      prompt_template = nil,
    },
  },
  vision = {
    temperature = 0.4,
    top_p = 0.9,
    max_tokens = 4096,
    completion = {
      max_lines = 1,
      temperature = 0.3,
      top_p = 0.9,
      max_tokens = 64,
      stop_sequences = { "\n" },
      prompt_template = nil,
    },
  },
  -- Define your custom models in ~/.config/nvim/lua/custom_ai_config.lua
}