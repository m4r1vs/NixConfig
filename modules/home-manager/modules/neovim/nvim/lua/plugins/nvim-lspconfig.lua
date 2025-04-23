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

    local c = require("lspconfig")

    -- Hyprland Configs
    c.hyprls.setup({})
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

    c.docker_compose_language_service.setup({})

    -- Helm
    vim.filetype.add({
      pattern = {
        ["values%.yaml"] = "helm",
        ["values%.yml"] = "helm",
        ["Chart%.yaml"] = "helm",
        ["Chart%.yml"] = "helm"
      },
    })

    c.helm_ls.setup({
      settings = {
        ["helm-ls"] = {
          yamlls = {
            path = "yaml-language-server"
          }
        }
      }
    })

    -- Bash
    c.bashls.setup({
      filetypes = {
        "bash", "sh", "zsh"
      }
    })

    -- Kotlin
    c.kotlin_language_server.setup({
      init_options = {
        storagePath = vim.fn.stdpath("cache") .. "/kotlinlsp",
      },
      filetypes = {
        "kotlin"
      }
    })

    -- Other ones without config

    c.clangd.setup({})
    c.cssls.setup({})
    c.dockerls.setup({})
    c.eslint.setup({})
    c.gitlab_ci_ls.setup({})
    c.golangci_lint_ls.setup({})
    c.gopls.setup({})
    c.html.setup({})
    c.jdtls.setup({})
    c.jsonls.setup({})
    c.lua_ls.setup({})
    c.marksman.setup({})
    c.nil_ls.setup({})
    c.nixd.setup({})
    c.pyright.setup({})
    c.rust_analyzer.setup({})
    c.taplo.setup({})
    c.terraformls.setup({})
    c.texlab.setup({})
    c.tinymist.setup({})
    c.vtsls.setup({})
    c.yamlls.setup({})
    c.zls.setup({})

    -- c.ccls.setup({})

    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    capabilities.textDocument.foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true
    }

    local configs = require("lspconfig.configs")
    for server, config in ipairs(configs) do
      if config.manager ~= nil then
        c[server].setup({
          capabilities = capabilities
        })
      end
    end
  end,
}
