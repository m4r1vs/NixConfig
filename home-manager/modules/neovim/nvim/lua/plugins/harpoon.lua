-- Quickly jump between specified files
return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>a",  function() require("harpoon"):list():add() end,                                    mode = "n", desc = "Add file to harpoon" },
    { "<F9>",       function() require("harpoon"):list():select(1) end,                                mode = "n", desc = "Select first harpoon mark" },
    { "<F10>",      function() require("harpoon"):list():select(2) end,                                mode = "n", desc = "Select second harpoon mark" },
    { "<F11>",      function() require("harpoon"):list():select(3) end,                                mode = "n", desc = "Select third harpoon mark" },
    { "<F12>",      function() require("harpoon"):list():select(4) end,                                mode = "n", desc = "Select fourth harpoon mark" },
    { "<leader>sh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, mode = "n", desc = "Toggle harpoon quick menu" },
    { "<leader>H",  function() require("harpoon"):list():add() end,                                    mode = "n", desc = "Add file to harpoon" },
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
