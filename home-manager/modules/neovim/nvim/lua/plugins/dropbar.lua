-- Show Treesitter/LSP objects as breadcrumbs in the top row.
return {
  "Bekaboo/dropbar.nvim",
  dependencies = {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make"
  },
  event = "VeryLazy",
  keys = {
    {
      "<leader>;",
      ":lua require(\"dropbar.api\").pick()<CR>",
      desc = "Use dropbar picker",
      mode = { "n" }
    },
  },
  opts = {
    bar = {
      sources = function(buf, _)
        local sources = require("dropbar.sources")
        local utils = require("dropbar.utils")
        if vim.bo[buf].ft == "markdown" then
          return {
            utils.source.fallback({
              sources.lsp,
              sources.markdown,
            }),
          }
        end
        if vim.bo[buf].buftype == "terminal" then
          return {
            sources.terminal,
          }
        end
        return {
          utils.source.fallback({
            sources.lsp,
            sources.treesitter,
          }),
        }
      end,
    },
  },
}
