-- Quickly create and save snippets
return {
  "chrisgrieser/nvim-scissors",
  dependencies = "nvim-telescope/telescope.nvim",
  keys = {
    { "<leader>ne", "<cmd>ScissorsEditSnippet<CR>",   desc = "Edit Snippet" },
    { "<leader>na", "<cmd>ScissorsAddNewSnippet<CR>", mode = "x",           desc = "Add Snippet" },
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
