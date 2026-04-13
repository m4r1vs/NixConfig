return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  version = false,
  opts = {
    select = {
      -- Automatically jump forward to textobj, similar to targets.vim
      lookahead = true,
      -- You can choose the select mode (default is charwise 'v')
      --
      -- Can also be a function which gets passed a table with the keys
      -- * query_string: eg '@function.inner'
      -- * method: eg 'v' or 'o'
      -- and should return the mode ('v', 'V', or '<c-v>') or a table
      -- mapping query_strings to modes.
      selection_modes = {
        ["@parameter.outer"] = "v", -- charwise
        ["@function.outer"] = "V",  -- linewise
        ["@class.outer"] = "<c-v>", -- blockwise
      },
      -- If you set this to `true` (default is `false`) then any textobject is
      -- extended to include preceding or succeeding whitespace. Succeeding
      -- whitespace has priority in order to act similarly to eg the built-in
      -- `ap`.
      --
      -- Can also be a function which gets passed a table with the keys
      -- * query_string: eg '@function.inner'
      -- * selection_mode: eg 'v'
      -- and should return true of false
      include_surrounding_whitespace = false,
    },
    move = {
      set_jumps = true,
    },
  },
  init = function()
    vim.g.no_plugin_maps = true
  end,
  config = function()
    -- Innter/Outer Method/Function
    vim.keymap.set({ "x", "o" }, "am", function()
      require "nvim-treesitter-textobjects.select".select_textobject("@function.outer", "textobjects")
    end)
    vim.keymap.set({ "x", "o" }, "im", function()
      require "nvim-treesitter-textobjects.select".select_textobject("@function.inner", "textobjects")
    end)

    -- Inner/Outer Class
    vim.keymap.set({ "x", "o" }, "ac", function()
      require "nvim-treesitter-textobjects.select".select_textobject("@class.outer", "textobjects")
    end)
    vim.keymap.set({ "x", "o" }, "ic", function()
      require "nvim-treesitter-textobjects.select".select_textobject("@class.inner", "textobjects")
    end)

    -- Inner/Outer Blockgg
    vim.keymap.set({ "x", "o" }, "ag", function()
      require "nvim-treesitter-textobjects.select".select_textobject("@block.outer", "textobjects")
    end)
    vim.keymap.set({ "x", "o" }, "ig", function()
      require "nvim-treesitter-textobjects.select".select_textobject("@block.inner", "textobjects")
    end)

    -- Swap with prev/next
    vim.keymap.set("n", "<leader>a", function()
      require("nvim-treesitter-textobjects.swap").swap_next "@parameter.inner"
    end)
    vim.keymap.set("n", "<leader>A", function()
      require("nvim-treesitter-textobjects.swap").swap_previous "@parameter.outer"
    end)

    -- Move around

    -- Next/Previous Method/Function
    vim.keymap.set({ "n", "x", "o" }, "]m", function()
      require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[m", function()
      require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "]M", function()
      require("nvim-treesitter-textobjects.move").goto_next_end("@function.outer", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[M", function()
      require("nvim-treesitter-textobjects.move").goto_previous_end("@function.outer", "textobjects")
    end)

    -- Next/Previous Class
    vim.keymap.set({ "n", "x", "o" }, "]c", function()
      require("nvim-treesitter-textobjects.move").goto_next_start("@class.outer", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[c", function()
      require("nvim-treesitter-textobjects.move").goto_previous_start("@class.outer", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "]C", function()
      require("nvim-treesitter-textobjects.move").goto_next_end("@class.outer", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[C", function()
      require("nvim-treesitter-textobjects.move").goto_previous_end("@class.outer", "textobjects")
    end)

    -- Next/Previous Blockgg
    vim.keymap.set({ "n", "x", "o" }, "]g", function()
      require("nvim-treesitter-textobjects.move").goto_next_start("@block.outer", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[g", function()
      require("nvim-treesitter-textobjects.move").goto_previous_start("@block.outer", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "]G", function()
      require("nvim-treesitter-textobjects.move").goto_next_end("@block.outer", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[G", function()
      require("nvim-treesitter-textobjects.move").goto_previous_end("@block.outer", "textobjects")
    end)

    -- Next/Previous Folds
    vim.keymap.set({ "n", "x", "o" }, "]z", function()
      require("nvim-treesitter-textobjects.move").goto_next_start("@fold", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[z", function()
      require("nvim-treesitter-textobjects.move").goto_previous_start("@fold", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "]Z", function()
      require("nvim-treesitter-textobjects.move").goto_next_end("@fold", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[Z", function()
      require("nvim-treesitter-textobjects.move").goto_previous_end("@fold", "textobjects")
    end)

    -- Next/Previous local
    vim.keymap.set({ "n", "x", "o" }, "]s", function()
      require("nvim-treesitter-textobjects.move").goto_next_start("@local.scope", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[s", function()
      require("nvim-treesitter-textobjects.move").goto_previous_start("@local.scope", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "]S", function()
      require("nvim-treesitter-textobjects.move").goto_next_end("@local.scope", "textobjects")
    end)
    vim.keymap.set({ "n", "x", "o" }, "[S", function()
      require("nvim-treesitter-textobjects.move").goto_previous_end("@local.scope", "textobjects")
    end)

    -- Make it ;/, repeatable
    local ts_repeat_move = require "nvim-treesitter-textobjects.repeatable_move"
    vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
    vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)
  end
}
