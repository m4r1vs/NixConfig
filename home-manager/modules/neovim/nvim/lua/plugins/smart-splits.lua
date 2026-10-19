return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  dependencies = {
    {
      "smart-splits-nvim/backend-tmux",
      main = "smart-splits-backend-tmux",
      opts = {
        disable_nav_when_zoomed = true,
      },
    },
  },
  init = function()
    vim.keymap.set('n', '<C-A-h>', require('smart-splits').resize_left)
    vim.keymap.set('n', '<C-A-j>', require('smart-splits').resize_down)
    vim.keymap.set('n', '<C-A-k>', require('smart-splits').resize_up)
    vim.keymap.set('n', '<C-A-l>', require('smart-splits').resize_right)
    -- moving between splits
    vim.keymap.set('n', '<C-h>', require('smart-splits').move_cursor_left)
    vim.keymap.set('n', '<C-j>', require('smart-splits').move_cursor_down)
    vim.keymap.set('n', '<C-k>', require('smart-splits').move_cursor_up)
    vim.keymap.set('n', '<C-l>', require('smart-splits').move_cursor_right)
    -- swapping buffers between windows
    vim.keymap.set('n', '<C-S-H>', require('smart-splits').swap_buf_left)
    vim.keymap.set('n', '<C-S-J>', require('smart-splits').swap_buf_down)
    vim.keymap.set('n', '<C-S-K>', require('smart-splits').swap_buf_up)
    vim.keymap.set('n', '<C-S-L>', require('smart-splits').swap_buf_right)
  end,
  opts = {
    ignored_buftypes = {
      "nofile",
      "quickfix",
      "prompt",
    },
    ignored_filetypes = { "NvimTree" },
    resize = {
      amount = 6,
      ignored_events = {
        "BufEnter",
        "WinEnter",
      },
    },
    move = {
      at_edge = "stop",
      same_row = false,
      float = "previous",
    },
    swap = {
      move_cursor = false,
    },
    mux = {
      backend = "smart-splits-backend-tmux",
    },
    log = {
      level = "info",
    },
  },
}

