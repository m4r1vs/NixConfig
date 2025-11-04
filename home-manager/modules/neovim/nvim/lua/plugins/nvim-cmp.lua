-- Autocompletions using different providers
return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "onsails/lspkind.nvim",
    "hrsh7th/cmp-cmdline",
    "hrsh7th/cmp-calc",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
  },
  event = "InsertEnter",
  init = function()
    local cmp = require("cmp")
    local lspkind = require("lspkind")
    local cmp_autopairs = require("nvim-autopairs.completion.cmp")
    cmp.event:on(
      "confirm_done",
      cmp_autopairs.on_confirm_done()
    )

    require("luasnip.loaders.from_vscode").lazy_load({
      paths = { "~/NixConfig/modules/home-manager/modules/neovim/nvim/snippets" }
    })

    local ls = require("luasnip")

    vim.keymap.set({ "i", "s" }, "<C-l>", function() ls.jump(1) end, { silent = true })
    vim.keymap.set({ "i", "s" }, "<C-h>", function() ls.jump(-1) end, { silent = true })

    cmp.setup({

      snippet = {
        expand = function(args)
          ls.lsp_expand(args.body)
        end,
      },

      enabled = function()
        local context = require "cmp.config.context"
        if vim.api.nvim_get_mode().mode == "c" then
          return true
        else
          return not context.in_treesitter_capture("comment")
              and not context.in_syntax_group("Comment")
        end
      end,

      window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      },

      formatting = {
        format = lspkind.cmp_format({
          mode = "symbol",
          maxwidth = {
            menu = 50,
            abbr = 50,
          },
          ellipsis_char = "...",
          show_labelDetails = true,
          before = function(_, vim_item)
            return vim_item
          end
        }),
        fields = { "kind", "abbr", "menu" },
        expandable_indicator = true,
      },

      mapping = cmp.mapping.preset.insert({
        ["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-e>"] = cmp.mapping.scroll_docs(-4),
        ["<C-y>"] = cmp.mapping.scroll_docs(4),
        ["<C-l>"] = cmp.mapping(
          cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Insert,
            select = false,
          }),
          { "i", "c" })
      }),

      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "path" },
        { name = "calc" },
      }, {
        { name = "buffer" },
      }),

      view = {
        entries = "custom",
        selection_order = "near_cursor"
      }

    })

    cmp.setup.cmdline({ "/", "?" }, {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = "buffer" }
      }
    })

    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = "path" },
      }, {
        { name = "cmdline" }
      }),
    })
  end
}
