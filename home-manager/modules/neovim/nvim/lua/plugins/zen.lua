-- Focus on a single pane of code
return {
  "m4r1vs/zen-mode.nvim",
  keys = {
    { "<leader>zm", "<cmd>ZenMode<cr>" },
  },
  opts = {
    window = {
      backdrop = 1,
      width = 130,
      height = 0.92,
      options = {
      },
    },
    plugins = {
      options = {
        enabled = true,
        ruler = false,
        showcmd = false,
        laststatus = 0,
      },
      twilight = { enabled = false },
      gitsigns = { enabled = false },
      tmux = { enabled = true },
      todo = { enabled = false },
      alacritty = {
        enabled = false,
      },
    },
  }
}
