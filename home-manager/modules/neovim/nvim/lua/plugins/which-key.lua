-- Popup for keybindings
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern", -- modern, helix, classic
    dealy = 400,
    icons = {
      enabled = false,
      mappings = true,
      rules = false,
    },
    spec = {
      { "<leader>s", group = "Search" },
      { "<leader>g", group = "Git" },
      { "<leader>l", group = "LSP" },
      { "<leader>e", group = "Yazi File Manager" },
      { "<leader>r", group = "Replace/Refactor" },
      { "<leader>n", group = "Snippets" },
      { "<leader>h", group = "Harpoon" },
      { "<leader>z", group = "Zen Mode" },
      { "<leader>m", group = "Copilot" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
