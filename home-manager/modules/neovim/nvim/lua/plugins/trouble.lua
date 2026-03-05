-- Better quickfix UI
return {
  "folke/trouble.nvim",
  opts = {},
  cmd = "Trouble",
  keys = {
    {
      "<leader>ll",
      "<cmd>Trouble diagnostics toggle focus=true win.type=split win.position=bottom win.size=0.35<cr>",
      desc = "Diagnostics (Trouble)",
    },
    {
      "<leader>lL",
      "<cmd>Trouble diagnostics filter.buf=0 win.type=split win.position=bottom win.size=0.35<cr>",
      desc = "Buffer Diagnostics (Trouble)",
    },
  },
}
