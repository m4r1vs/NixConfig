-- UI for fuzzy finding anything
return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  event = "VeryLazy",
  init = function()
    local telescope = require("telescope.builtin")
    vim.keymap.set("n", "<leader>sf", telescope.find_files, { desc = "Telescope find files" })
    vim.keymap.set("n", "<leader>st", telescope.treesitter, { desc = "Telescope Treesitter" })
    vim.keymap.set("n", "<leader>sr", telescope.live_grep, { desc = "Telescope live grep" })
    vim.keymap.set("n", "<leader>sb", telescope.buffers, { desc = "Telescope buffers" })
    vim.keymap.set("n", "<leader>sd", telescope.buffers, { desc = "Telescope diagnostics" })
  end,
  opts = {
    extensions = {
      fzf = {
        fuzzy = true,                   -- false will only do exact matching
        override_generic_sorter = true, -- override the generic sorter
        override_file_sorter = true,    -- override the file sorter
        case_mode = "smart_case",       -- or "ignore_case" or "respect_case"
      },
    },
    pickers = {
      live_grep = {
        hidden = true,
        prompt_title = "R.I.P. Grep",
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--hidden",
          "--glob=!.git/",
          "--smart-case",
          "--trim"
        },
      },
      buffers = {
        initial_mode = "normal",
        theme = "cursor",
        previewer = false
      },
      find_files = {
        hidden = true,
        theme = "dropdown",
        file_ignore_patterns = { ".git/" },
      },
    },
  }
}
