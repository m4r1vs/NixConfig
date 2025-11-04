-- Nice transparent neovim theme
return {
  "scottmckendry/cyberdream.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    transparent = true,
    italic_comments = true,
    hide_fillchars = true,
    borderless_pickers = true,
    cache = false,
    variant = "auto",
    highlights = {
      TabLineSel = { fg = "#000000", bg = os.getenv("PRIMARY_COLOR") },
      IblScope = { fg = os.getenv("PRIMARY_COLOR"), bg = "NONE" },
      LeapLabelPrimary = { fg = "#000000", bg = os.getenv("PRIMARY_COLOR"), bold = true },
      AlphaHeader = { fg = os.getenv("PRIMARY_COLOR"), bg = "NONE" },
      YankHighlight = { bg = os.getenv("PRIMARY_COLOR") }
    },
    extensions = {
      telescope = true,
      leap = false,
      mini = true,
      gitsigns = true,
      lazy = true,
      trouble = true,
      treesitter = true,
      base = true,
    }
  }
}
