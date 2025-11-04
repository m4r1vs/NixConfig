-- Tools for working with LaTeX. Leader+ll for live-preview using zathura
return {
  "lervag/vimtex",
  ft = { "tex" },
  init = function()
    vim.g.vimtex_view_method = "zathura"
  end
}
