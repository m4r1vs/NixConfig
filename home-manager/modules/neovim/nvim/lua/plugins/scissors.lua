-- Quickly create and save snippets
return {
  "chrisgrieser/nvim-scissors",
  dependencies = "nvim-telescope/telescope.nvim",
  keys = {
    { "<leader>ne", "<cmd>ScissorsEditSnippet<CR>" },
    { "<leader>na", "<cmd>ScissorsAddNewSnippet<CR>", mode = "x" },
  },
  opts = {
    telescope = {
      alsoSearchSnippetBody = true,
    },
    snippetDir = "~/NixConfig/modules/home-manager/modules/neovim/nvim/snippets",
    backdrop = {
      enabled = false,
    }
  },
}
