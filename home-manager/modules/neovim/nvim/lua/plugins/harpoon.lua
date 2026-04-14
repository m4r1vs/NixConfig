-- Quickly jump between specified files
return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>h1", function() require("harpoon"):list():select(1) end,                                mode = "n", desc = "Select first harpoon mark" },
    { "<leader>h2", function() require("harpoon"):list():select(2) end,                                mode = "n", desc = "Select second harpoon mark" },
    { "<leader>h3", function() require("harpoon"):list():select(3) end,                                mode = "n", desc = "Select third harpoon mark" },
    { "<leader>h4", function() require("harpoon"):list():select(4) end,                                mode = "n", desc = "Select fourth harpoon mark" },
    { "<leader>hh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, mode = "n", desc = "Toggle harpoon quick menu" },
    { "<leader>ha", function() require("harpoon"):list():add() end,                                    mode = "n", desc = "Add file to harpoon" },
    { "<leader>hp", function() require("harpoon"):list():prev() end,                                   mode = "n", desc = "Previous harpoon mark" },
    { "<leader>hn", function() require("harpoon"):list():next() end,                                   mode = "n", desc = "Next harpoon mark" },
  },
  opts = {
    settings = {
      save_on_toggle = true,
      sync_on_ui_close = true
    }
  },
}
