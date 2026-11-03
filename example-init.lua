-- Example Neovim init.lua for custom_ai.nvim
-- Copy relevant sections into your own config

-- Set leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load custom_ai
local custom_ai = require("custom_ai")

custom_ai.setup({
  server = {
    host = "127.0.0.1",
    port = 9931,
  },

  models = {
    allrounder = "Nemotron-Bolt-E4B Q5_K (allrounder: 65K, reasoning, tools)",
    coder      = "Qwen3 8B Q4 (coder: 24K, reasoning, tools)",
    specialist = "Qwen2.5-Coder 7B Q6_K Instruct (specialist: 32K native)",
    efficient  = "Qwen3.5 4B Q8 (efficient: 16K, reasoning, tools)",
    vision     = "LLaVA-NeXT-8B Q6_K (vision: 4K, multimodal, OCR)",
  },

  scripts = {
    allrounder = "~/llama/scripts/llm-allrounder.sh",
    coder      = "~/llama/scripts/llm-coder.sh",
    specialist = "~/llama/scripts/llm-specialist.sh",
    efficient  = "~/llama/scripts/llm-efficient.sh",
    vision     = "~/llama/scripts/llm-vision.sh",
  },

  keymaps = {
    send_msg    = "<leader>as",
    vision_msg  = "<leader>av",
    new_chat    = "<leader>an",
    toggle_chat = "<leader>.",
    run_tests   = "<leader>at",
    edit_code   = "<leader>ae",
    ask_file    = "<leader>af",
    edit_sel    = "<leader>ah",
    show_scripts= "<leader>ai",
  },
})

-- AI keymaps
vim.keymap.set("n", "<leader>.", custom_ai.chat, { desc = "Toggle AI chat" })
vim.keymap.set("n", "<leader>as", function() end, { desc = "Send AI message (in chat)" })
vim.keymap.set("n", "<leader>av", function() end, { desc = "Send AI message + image (in chat)" })
vim.keymap.set("n", "<leader>af", custom_ai.ask_file, { desc = "Ask AI about file" })
vim.keymap.set("n", "<leader>ae", custom_ai.edit_code, { desc = "Edit code with AI" })
vim.keymap.set("n", "<leader>ah", custom_ai.edit_selection, { desc = "AI edit selection" })
vim.keymap.set("n", "<leader>at", custom_ai.run_tests, { desc = "Run tests with AI" })
vim.keymap.set("n", "<leader>ai", custom_ai.show_scripts, { desc = "Show AI scripts" })
vim.keymap.set("n", "<leader>an", custom_ai.new_chat, { desc = "New AI chat" })

-- Optional: auto-check server on startup
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      custom_ai.check_server_on_startup()
    end, 500)
  end,
  once = true,
})