return {
  "zbirenbaum/copilot.lua",
  dependencies = { {
    "copilotlsp-nvim/copilot-lsp",
    version = false,
    event = "InsertEnter",
    init = function()
      vim.g.copilot_nes_debounce = 500
    end,
  } },
  version = false,
  event = "InsertEnter",
  config = function()
    require("copilot").setup({
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          next = "<M-j>",
          prev = "<M-k>",
          accept = "<M-m>",
        },
      },
      panel = {
        enabled = false,
      },
      nes = {
        enabled = false,
      },
    })

    vim.g.copilot_autotrigger = false

    -- <leader>cc toggles copilot autotrigger
    vim.keymap.set("n", "<leader>cc", function()
      require("copilot.suggestion").toggle_auto_trigger()
      vim.g.copilot_autotrigger = not vim.g.copilot_autotrigger
      print("Copilot autotrigger " .. (vim.g.copilot_autotrigger and "enabled" or "disabled"))
    end, { desc = "Toggle Copilot autotrigger" })
  end,
}
