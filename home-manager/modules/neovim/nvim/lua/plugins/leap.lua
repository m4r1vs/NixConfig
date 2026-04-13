-- Quickly leap from point-to-point
return {
  "https://codeberg.org/andyg/leap.nvim.git",
  name = "leap",
  keys = {
    { "s",  mode = { "n", "x", "o" }, desc = "Leap forward" },
    { "S",  mode = { "n", "x", "o" }, desc = "Leap backward" },
    { "gs", mode = { "n", "x", "o" }, desc = "Leap from window" },
    { "x",  mode = { "x", "o" },      desc = "Leap forward till" },
    { "X",  mode = { "x", "o" },      desc = "Leap backward till" },
    { "gS", mode = { "n", "o" },      desc = "Leap remote" },
    { "R",  mode = { "x", "o" },      desc = "Treesitter node selection" },
  },
  config = function()
    -- Define the actual leap mappings for all relevant modes
    -- remap = true is required when mapping to <Plug> targets
    vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap-forward)", { remap = true, desc = "Leap forward" })
    vim.keymap.set({ "n", "x", "o" }, "S", "<Plug>(leap-backward)", { remap = true, desc = "Leap backward" })
    vim.keymap.set({ "n", "x", "o" }, "gs", "<Plug>(leap-from-window)", { remap = true, desc = "Leap from window" })
    -- till mappings are only for visual and operator-pending mode
    vim.keymap.set({ "x", "o" }, "x", "<Plug>(leap-forward-till)", { remap = true, desc = "Leap forward till" })
    vim.keymap.set({ "x", "o" }, "X", "<Plug>(leap-backward-till)", { remap = true, desc = "Leap backward till" })

    -- Remote action
    vim.keymap.set({ "n", "o" }, "gS", function()
      require("leap.remote").action()
    end, { desc = "Leap remote" })

    -- Treesitter node selection
    vim.keymap.set({ 'x', 'o' }, 'R', function()
      require('leap.treesitter').select {
        opts = require('leap.user').with_traversal_keys('R', 'r')
      }
    end)
  end,
}
