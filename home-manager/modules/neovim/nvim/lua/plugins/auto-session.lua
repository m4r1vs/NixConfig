-- Automatically store and load sessions.
-- Remember splits, tabs, etc.
return {
  "rmagatti/auto-session",
  lazy = false,
  keys = {
    { "<leader>ss", "<cmd>AutoSession search<CR>", desc = "Session search" },
    { "<leader>S",  "<cmd>AutoSession save<CR>",   desc = "Session save" },
  },

  ---enables autocomplete for opts
  ---@module "auto-session"
  ---@type AutoSession.Config
  opts = {
    auto_save = true,
    auto_create = function()
      local cmd = '[ -d .git ] && echo true || echo false'
      return vim.fn.system(cmd) == 'true\n'
    end,
    suppressed_dirs = { "~/", "/run/*" },
    auto_restore = true,
    cwd_change_handling = true,
    bypass_save_filetypes = { "alpha", "dashboard" },
    session_lens = {
      load_on_setup = true,
      previewer = false,
      mappings = {
        delete_session = { "i", "<C-D>" },
        alternate_session = { "i", "<C-S>" },
        copy_session = { "i", "<C-Y>" },
      },
      theme_conf = {
        border = true,
      },
    },
  }
}
