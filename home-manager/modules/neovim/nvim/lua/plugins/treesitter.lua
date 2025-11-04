local parser_install_dir = vim.fn.stdpath("cache") .. "/treesitters"
vim.fn.mkdir(parser_install_dir, "p")
vim.opt.runtimepath:append(parser_install_dir)

return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = "VeryLazy",
  init = function()
    local configs = require("nvim-treesitter.configs")

    configs.setup({
      parser_install_dir = parser_install_dir,
      auto_install = true,
      ensure_installed = {
        "javascript",
        "typescript",
        "rust",
        "python",
        "go",
        "c",
        "lua",
        "vim",
        "query",
        "html",
        "css",
        "arduino",
        "cpp",
        "dart",
        "json",
        "julia",
        "lua",
        "markdown_inline",
        "markdown",
        "make",
        "regex",
        "ruby",
        "scss",
        "sql",
        "svelte",
        "vimdoc",
        "yaml",
        "xml",
        "dot",
        "zig",
      },
      sync_install = false,
      highlight = {
        enable = true,
        disable = { "latex" },
        additional_vim_regex_highlighting = { "latex", "markdown" },
      },
      indent = { enable = true },
    })
  end
}
