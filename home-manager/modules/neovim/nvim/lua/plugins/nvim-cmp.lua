-- Autocompletions using different providers
return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-cmdline",
    "hrsh7th/cmp-calc",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
  },
  event = "InsertEnter",
  init = function()
    local cmp = require("cmp")
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
        completion = {
          border = "rounded",
          col_offset = -1,
          side_padding = 1,
        },
        documentation = {
          border = "rounded",
          side_padding = 1,
        },
      },

      formatting = {
        fields = { "abbr", "kind", "menu" },
        format = function(entry, vim_item)
          vim_item.kind = (({
            Text = "  ",
            Method = "  󰆧",
            Function = "  󰊕",
            Constructor = "  ",
            Field = "  󰇽",
            Variable = "  󰂡",
            Class = "  󰠱",
            Interface = "  ",
            Module = "  ",
            Property = "  󰜢",
            Unit = "  ",
            Value = "  󰎠",
            Enum = "  ",
            Keyword = "  󰌋",
            Snippet = "  ",
            Color = "  󰏘",
            File = "  󰈙",
            Reference = "  ",
            Folder = "  󰉋",
            EnumMember = "  ",
            Constant = "  󰏿",
            Struct = "  ",
            Event = "  ",
            Operator = "  󰆕",
            TypeParameter = "  󰅲",
          })[vim_item.kind] or " ") .. string.format(" (%s)", vim_item.kind)
          vim_item.menu = ({
            buffer = "",
            nvim_lsp = "󱠂",
            luasnip = "",
            nvim_lua = "",
            latex_symbols = "",
          })[entry.source.name]
          return vim_item
        end
      },

      mapping = cmp.mapping.preset.insert({
        ["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
        ["<C-e>"] = cmp.mapping.scroll_docs(-4),
        ["<C-y>"] = cmp.mapping.scroll_docs(4),
        ["<C-d>"] = cmp.mapping.open_docs(),
        ["<C-u>"] = cmp.mapping.close_docs(),
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
