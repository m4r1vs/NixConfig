return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  opts = {},
  config = function()
    local parsers = {
      "arduino",
      "bash",
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
    }
    require("nvim-treesitter").setup {}
    require("nvim-treesitter").install(parsers)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = parsers,
      callback = function()
        vim.treesitter.start()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        vim.wo[0][0].foldmethod = 'expr'
      end,
    })
  end,
}
