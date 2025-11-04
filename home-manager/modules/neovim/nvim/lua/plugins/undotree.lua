-- Timetravel in NeoVim

return {
  "mbbill/undotree",
  keys = {
    { "<leader>su", vim.cmd.UndotreeToggle },
  },
}
