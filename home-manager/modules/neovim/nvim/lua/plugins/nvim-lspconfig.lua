-- Preconfigured settings for language servers
return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-cmdline",
    "hrsh7th/nvim-cmp",
    {
      "towolf/vim-helm",
      ft = { "yaml" }
    },
  },
  event = "VeryLazy",
  init = function()
    vim.api.nvim_create_autocmd("LspAttach", {
      desc = "LSP actions",
      callback = function(args)
        local opts = { buffer = args.buf }

        local client = vim.lsp.get_client_by_id(args.data.client_id)

        if client ~= nil then
          require("workspace-diagnostics").populate_workspace_diagnostics(client, args.buf)
        end

        vim.keymap.set("n", "K", "<cmd>lua vim.lsp.buf.hover({border = 'rounded'})<cr>", opts)
        vim.keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<cr>", opts)
        vim.keymap.set("n", "gD", "<C-w>v<cmd>Telescope lsp_definitions<cr>", opts)
        vim.keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<cr>", opts)
        vim.keymap.set("n", "go", "<cmd>Telescope lsp_type_definitions<cr>", opts)
        vim.keymap.set("n", "gr", "<cmd>Telescope lsp_references<cr>", opts)
        vim.keymap.set("n", "<C-s>", "<cmd>lua vim.lsp.buf.signature_help()<cr>", opts)
        vim.keymap.set("i", "<C-s>", "<cmd>lua vim.lsp.buf.signature_help()<cr>", opts)
        vim.keymap.set("n", "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<cr>", opts)
        vim.keymap.set("n", "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", opts)
        vim.keymap.set("n", "<leader>lk", "<cmd>lua vim.diagnostic.goto_prev()<cr>", opts)
        vim.keymap.set("n", "<leader>lj", "<cmd>lua vim.diagnostic.goto_next()<cr>", opts)
      end,
    })

    -- Hyprland Configs
    vim.lsp.enable("hyprls")
    vim.filetype.add({
      pattern = { [".*/hypr/.*%.conf"] = "hyprlang" },
    })

    -- Rasi (No lsp, just treesitter)
    vim.filetype.add({
      pattern = { [".*%.rasi"] = "rasi" },
    })

    -- Docker Compose
    vim.filetype.add({
      pattern = {
        ["docker%-compose%.yml"] = "yaml.docker-compose",
        ["docker%-compose%.yaml"] = "yaml.docker-compose",
        ["compose%.yml"] = "yaml.docker-compose",
        ["compose%.yaml"] = "yaml.docker-compose",
        ["compose/.*%.yml"] = "yaml.docker-compose",
        ["compose/.*%.yaml"] = "yaml.docker-compose",
      },
    })

    -- Helm
    vim.filetype.add({
      pattern = {
        ["values%.yaml"] = "helm",
        ["values%.yml"] = "helm",
        ["Chart%.yaml"] = "helm",
        ["Chart%.yml"] = "helm"
      },
    })

    -- Bash
    vim.lsp.enable("bashls")
    vim.lsp.config("bashls", {
      filetypes = {
        "bash", "sh", "zsh"
      }
    })

    -- Other ones without config

    vim.lsp.enable("clangd")
    vim.lsp.enable("cssls")
    vim.lsp.enable("docker_compose_language_service")
    vim.lsp.enable("dockerls")
    vim.lsp.enable("eslint")
    vim.lsp.enable("gitlab_ci_ls")
    vim.lsp.enable("golangci_lint_ls")
    vim.lsp.enable("gopls")
    vim.lsp.enable("helm_ls")
    vim.lsp.enable("html")
    vim.lsp.enable("jdtls")
    vim.lsp.enable("jsonls")
    vim.lsp.enable("lua_ls")
    vim.lsp.enable("marksman")
    vim.lsp.enable("nil_ls")
    vim.lsp.enable("nixd")
    vim.lsp.enable("pyright")
    vim.lsp.enable("rust_analyzer")
    vim.lsp.enable("sourcekit")
    vim.lsp.enable("taplo")
    vim.lsp.enable("terraformls")
    vim.lsp.enable("texlab")
    vim.lsp.enable("tinymist")
    vim.lsp.enable("vtsls")
    vim.lsp.enable("yamlls")
    vim.lsp.enable("zls")

    -- Make sure each server knows what can and cannot be done using nvim-cmp

    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    capabilities.textDocument.foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true
    }

    local configs = require("lspconfig.configs")
    for server, config in ipairs(configs) do
      if config.manager ~= nil then
        vim.lsp.config(server, {
          capabilities = capabilities
        })
      end
    end
  end,
}
