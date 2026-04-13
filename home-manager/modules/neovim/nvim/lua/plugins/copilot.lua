return {
  "zbirenbaum/copilot.lua",
  version = false,
  event = "InsertEnter",
  keys = {
    { "<M-j>",      mode = "i", desc = "Next Copilot suggestion" },
    { "<M-k>",      mode = "i", desc = "Previous Copilot suggestion" },
    { "<M-m>",      mode = "i", desc = "Accept Copilot suggestion" },
    { "<M-w>",      mode = "i", desc = "Accept Copilot suggestion word" },
    { "<leader>mm", mode = "n", desc = "Toggle Copilot autotrigger" },
  },
  config = function()
    require("copilot").setup({
      suggestion = {
        enabled = true,
        auto_trigger = false,
        keymap = {
          next = "<M-j>",
          prev = "<M-k>",
          accept = "<M-m>",
          accept_word = "<M-w>",
        },
      },
      panel = {
        enabled = false,
      },
      nes = {
        enabled = false,
      },
    })

    -- toggle copilot autotrigger
    vim.keymap.set("n", "<leader>mm", function()
      require("copilot.suggestion").toggle_auto_trigger()
    end, { desc = "Toggle Copilot autotrigger" })
  end,
}
