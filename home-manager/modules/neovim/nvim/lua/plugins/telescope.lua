-- UI for fuzzy finding anything
return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  event = "VeryLazy",
  init = function()
    local telescope = require("telescope.builtin")
    vim.keymap.set("n", "<leader>sf", telescope.find_files, { desc = "Find Files" })
    vim.keymap.set("n", "<leader>st", telescope.treesitter, { desc = "Treesitter Symbols" })
    vim.keymap.set("n", "<leader>sr", telescope.live_grep, { desc = "R.I.P. Grep" })
    vim.keymap.set("n", "<leader>sb", telescope.buffers, { desc = "Buffers" })
    vim.keymap.set("n", "<leader>sd", telescope.diagnostics, { desc = "Workspace Diagnostics" })
    vim.keymap.set("n", "<leader>sp", telescope.planets, { desc = "Use a Telescope" })
    vim.keymap.set("n", "<leader>sc", telescope.commands, { desc = "VIM Commands" })
    vim.keymap.set("n", "<leader>sl", telescope.lsp_dynamic_workspace_symbols, { desc = "LSP Workspace Symbols" })
    vim.keymap.set("n", "<leader>sm", telescope.builtin, { desc = "Telescopes" })
  end,
  opts = {
    defaults = {
      mappings = {
        i = {
          ["<C-j>"] = require('telescope.actions').move_selection_next,
          ["<C-k>"] = require('telescope.actions').move_selection_previous,
          ["<C-l>"] = require('telescope.actions').select_default,
          ["<M-j>"] = require('telescope.actions').move_selection_next,
          ["<M-k>"] = require('telescope.actions').move_selection_previous,
        },
      },
    },
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
