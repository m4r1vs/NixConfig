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
      local cmd = '[ -d .git ] && echo -e true || echo -e false'
      return vim.fn.system(cmd) == 'true'
    end,
    suppressed_dirs = { "~/", "/run/*" },
    auto_restore = true,
    cwd_change_handling = true,
    bypass_save_filetypes = { "alpha", "dashboard" },
    session_lens = {
      load_on_setup = true,
      previewer = "summary",
      mappings = {
        delete_session = { "n", "<C-d>" },
        alternate_session = { "n", "<C-s>" },
      },
      theme_conf = {
        border = true,
      },
    },
  }
}
