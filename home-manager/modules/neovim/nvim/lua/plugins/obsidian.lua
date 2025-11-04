-- Tools for browsing Obsidian Markdown files
return {
  "epwalsh/obsidian.nvim",
  version = "*",
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  keys = {
    {
      "<leader>so",
      "<cmd>ObsidianQuickSwitch<cr>",
      desc = "Search Obsidian notes",
      mode = { "n" }
    },
  },
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/Documents/Marius' Remote Vault",
      },
    },
    disable_frontmatter = true,
    daily_notes = {
      folder = "Journal",
      date_format = "%Y-%m-%d",
    },
    note_id_func = function(title)
      return title
    end,
    templates = {
      folder = "Templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      substitutions = {},
    },
    ---@param url string
    follow_url_func = function(url)
      vim.ui.open(url)
    end,
  },
}
