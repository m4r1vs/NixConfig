-- Make neovim tabs beautiful
return {
  "m4r1vs/luatab.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    modified = function(bufnr)
      return vim.fn.getbufvar(bufnr, "&modified") == 1 and " " or " "
    end,
    windowCount = function()
      return ""
    end,
    separator = function()
      return "%#TabLine# "
    end
  }
}
