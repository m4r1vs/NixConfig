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
    saturation = 1, -- Value below 1 raises error on light/dark mode switch
    cache = false,  -- Enabling this breaks dark/light mode switch
    variant = "auto",
    highlights = {
      TabLineSel = { fg = "#000000", bg = os.getenv("PRIMARY_COLOR") },
      IblScope = { fg = os.getenv("PRIMARY_COLOR"), bg = "NONE" },
      LeapLabelPrimary = { fg = "#000000", bg = os.getenv("PRIMARY_COLOR"), bold = true },
      AlphaHeader = { fg = os.getenv("PRIMARY_COLOR"), bg = "NONE" },
      YankHighlight = { bg = os.getenv("PRIMARY_COLOR") }
    },
    colors = { -- Flexoki color palette
      dark = {
        magenta = "#AC698C",
        pink = "#DD8EB6",
        purple = "#8170A5",
        bg = "#15130F",
        bg_alt = "#181612",
        bg_highlight = "#1c1a16",
        orange = "#C48862",
        green = "#94A654",
        yellow = "#DEBE5B",
        red = "#B96D67",
        grey = "#ABAAA6",
        blue = "#7BAAD2",
        cyan = "#75C3BC",
        fg = "#e6e5df",
      },
      light = {
        magenta = "#a02f6f",
        pink = "#ce5d97",
        purple = "#8b7ec8",
        bg = "#fffcf0",
        bg_alt = "#dad8ce",
        bg_highlight = "#e6e4d9",
        orange = "#ad8301",
        green = "#879a39",
        yellow = "#d0a215",
        red = "#d14d41",
        grey = "#6f6e69",
        blue = "#4385be",
        cyan = "#24837b",
        fg = "#100f0f",
      },
    },
    extensions = {
      alpha = true,
      base = true,
      cmp = true,
      gitsigns = true,
      indentblankline = true,
      lazy = true,
      leap = false,
      markdown = true,
      markview = true,
      mini = true,
      telescope = true,
      treesitter = true,
      treesittercontext = true,
      trouble = true,
    }
  }
}
