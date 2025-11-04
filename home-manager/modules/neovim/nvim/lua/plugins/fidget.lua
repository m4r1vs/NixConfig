-- Show LSP notifications and status in bottom right corner
return {
  "j-hui/fidget.nvim",
  event = "VeryLazy",
  opts = {
    notification = {
      window = {
        winblend = 0,
        border = "none",
        zindex = 45,
        max_width = 0,
        max_height = 0,
        x_padding = 1,
        y_padding = 0,
        align = "bottom",
        relative = "editor",
      },
    },
  },
}
