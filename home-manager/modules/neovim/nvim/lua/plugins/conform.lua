-- Automatically run the configured formatter on save
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      -- Customize or remove this keymap to your liking
      "<leader>ff",
      function()
        require("conform").format({ async = true })
      end,
      mode = "",
      desc = "Format buffer",
    },
  },
  -- This will provide type hinting with LuaLS
  ---@module "conform"
  opts = {
    notify_no_formatters = false,
    formatters_by_ft = {
      css = { "prettierd", "prettier", stop_after_first = true },
      go = { "goimports", "gofmt" },
      javascript = { "prettierd", "prettier", stop_after_first = true },
      javascriptreact = { "prettierd", "prettier", stop_after_first = true },
      json = { "lsp_format" },
      lua = { "lsp_format" },
      markdown = { "lsp_format" },
      nix = { "alejandra" },
      python = { "isort", "black" },
      rust = { "rustfmt", lsp_format = "fallback" },
      scss = { "prettierd", "prettier", stop_after_first = true },
      svelte = { "prettierd", "prettier", stop_after_first = true },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      typst = { "typstyle" },
      ["_"] = { "trim_whitespace", "lsp_format" },
    },
    default_format_opts = {
      lsp_format = "fallback",
    },
    format_on_save = {
      lsp_format = "fallback",
      timeout_ms = 500,
    },
    formatters = {
      shfmt = {
        append_args = { "-i", "2" },
      },
    },
  },
}
