-- Show indent-lines generated using Treesitter context
return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  event = "VeryLazy",
  init = function()
    local indent_blankline_augroup = vim.api.nvim_create_augroup("indent_blankline_augroup", { clear = true })

    vim.api.nvim_create_autocmd("ModeChanged", {
      group = indent_blankline_augroup,
      pattern = "*:[vV\x16]*",
      callback = function()
        if vim.bo.buftype == "" then
          vim.cmd("IBLDisable")
        end
      end,
      desc = "Disable IBL for insert mode in normal buffers.",
    })

    vim.api.nvim_create_autocmd("ModeChanged", {
      group = indent_blankline_augroup,
      pattern = "[vV\x16]*:*",
      callback = function()
        if vim.bo.buftype == "" then
          vim.cmd("IBLEnable")
        end
      end,
      desc = "Enable IBL for insert mode in normal buffers.",
    })

    require("ibl").setup({
      enabled = true,
      indent = {
        char = "▏",
      },
      scope = {
        enabled = true,
        char = "▏",
        show_start = false,
        show_end = false,
      },
      whitespace = {
        remove_blankline_trail = false
      },
      exclude = {
        filetypes = {
          "lspinfo",
          "packer",
          "checkhealth",
          "help",
          "man",
          "gitcommit",
          "TelescopePrompt",
          "TelescopeResults",
          "dashboard",
        }
      }
    })
  end,
}
