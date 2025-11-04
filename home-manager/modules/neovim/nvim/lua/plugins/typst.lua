-- Start a live-preview server for typst projects and sync the cursor.

return {
  "chomosuke/typst-preview.nvim",
  ft = { "typst" },
  opts = {
    invert_colors = "auto",
    dependencies_bin = {
      ['websocat'] = "websocat",
      ['tinymist'] = 'tinymist'
    },
  },
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "typst",
      callback = function()
        vim.keymap.set("n", "<localleader>ll", ":TypstPreviewToggle<CR>", {
          buffer = true,
          silent = true,
          desc = "Toggle Preview of Typst document"
        })
      end
    })
  end
}
