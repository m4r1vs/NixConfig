-- Quickly surround text with characters
return {
  "kylechui/nvim-surround",
  event = "VeryLazy",
  opts = {
    nvim_surround_no_mappings = true,
  },
  init = function()
    vim.keymap.set("i", "<C-g>e", "<Plug>(nvim-surround-insert)", {
      desc = "Add a surrounding pair around the cursor (insert mode)",
    })
    vim.keymap.set("i", "<C-g>E", "<Plug>(nvim-surround-insert-line)", {
      desc = "Add a surrounding pair around the cursor, on new lines (insert mode)",
    })
    vim.keymap.set("n", "ye", "<Plug>(nvim-surround-normal)", {
      desc = "Add a surrounding pair around a motion (normal mode)",
    })
    vim.keymap.set("n", "yee", "<Plug>(nvim-surround-normal-cur)", {
      desc = "Add a surrounding pair around the current line (normal mode)",
    })
    vim.keymap.set("n", "yE", "<Plug>(nvim-surround-normal-line)", {
      desc = "Add a surrounding pair around a motion, on new lines (normal mode)",
    })
    vim.keymap.set("n", "yEE", "<Plug>(nvim-surround-normal-cur-line)", {
      desc = "Add a surrounding pair around the current line, on new lines (normal mode)",
    })
    vim.keymap.set("x", "E", "<Plug>(nvim-surround-visual)", {
      desc = "Add a surrounding pair around a visual selection",
    })
    vim.keymap.set("x", "gE", "<Plug>(nvim-surround-visual-line)", {
      desc = "Add a surrounding pair around a visual selection, on new lines",
    })
    vim.keymap.set("n", "de", "<Plug>(nvim-surround-delete)", {
      desc = "Delete a surrounding pair",
    })
    vim.keymap.set("n", "ce", "<Plug>(nvim-surround-change)", {
      desc = "Change a surrounding pair",
    })
    vim.keymap.set("n", "cE", "<Plug>(nvim-surround-change-line)", {
      desc = "Change a surrounding pair, putting replacements on new lines",
    })
  end,
}
