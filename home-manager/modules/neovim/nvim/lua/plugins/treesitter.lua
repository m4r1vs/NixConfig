local parser_install_dir = vim.fn.stdpath("cache") .. "/treesitters"
vim.fn.mkdir(parser_install_dir, "p")
vim.opt.runtimepath:append(parser_install_dir)

return {
  {
    "nvim-treesitter/nvim-treesitter",
    version = false,
    build = ":TSUpdate",
    event = "VeryLazy",
    branch = "master",
    opts = {
      parser_install_dir = parser_install_dir,
      highlight = {
        enable = true,
      },
      indent = { enable = true },
      ensure_installed = {
        "arduino",
        "c",
        "cpp",
        "css",
        "dart",
        "dot",
        "go",
        "html",
        "javascript",
        "json",
        "julia",
        "lua",
        "make",
        "markdown",
        "markdown_inline",
        "nix",
        "python",
        "query",
        "regex",
        "ruby",
        "rust",
        "scss",
        "sql",
        "svelte",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
        "zig",
      },
    },
  },
}
