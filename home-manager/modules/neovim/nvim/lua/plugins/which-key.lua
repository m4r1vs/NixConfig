-- Popup for keybindings
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "helix", -- modern, helix, classic
    delay = 800,
    icons = {
      enabled = false,
      mappings = true,
      rules = false,
    },
    spec = {
      { "<leader>s",  group = "Search" },
      { "<leader>g",  group = "Git" },
      { "<leader>l",  group = "LSP" },
      { "<leader>e",  group = "Yazi File Manager" },
      { "<leader>w",  group = "File Operations" },
      { "<leader>r",  group = "Replace/Refactor",    mode = { "x", "v", "n" } },
      { "<leader>rc", group = "Color Manipulations", mode = { "v" } },
      { "<leader>n",  group = "Snippets",            mode = { "x", "v", "n" } },
      { "<leader>h",  group = "Harpoon" },
      { "<leader>u",  group = "UI/UX" },
      { "<leader>m",  group = "Copilot" },
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
