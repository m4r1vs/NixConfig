-- Dashboard when opening neovim without session or file
return {
  "goolord/alpha-nvim",
  dependencies = { "echasnovski/mini.icons" },
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      [[⠀                                                                       ⠀]],
      [[⠀                                                                       ⠀]],
      [[⠀                                                                       ⠀]],
      [[⠀                                                                       ⠀]],
      [[⠀                                                                       ⠀]],
      [[⠀                                                                     ⠀]],
      [[⠀       ████ ██████           █████      ██                     ⠀]],
      [[⠀      ███████████             █████                             ⠀]],
      [[⠀      █████████ ███████████████████ ███   ███████████   ⠀]],
      [[⠀     █████████  ███    █████████████ █████ ██████████████   ⠀]],
      [[⠀    █████████ ██████████ █████████ █████ █████ ████ █████   ⠀]],
      [[⠀  ███████████ ███    ███ █████████ █████ █████ ████ █████  ⠀]],
      [[⠀ ██████  █████████████████████ ████ █████ █████ ████ ██████ ⠀]],
      [[⠀                                                                       ⠀]],
      [[⠀                                                                       ⠀]],
    }

    dashboard.section.header.opts.hl = "AlphaHeader"

    dashboard.section.buttons.val = {
      dashboard.button("s", "󰆋   Sessions", ":silent AutoSession search<CR>"),
      dashboard.button("u", "󰮭   Update Lazy", ":silent Lazy update<CR>"),
      dashboard.button("n", "   New Empty File", ":silent ene <BAR> startinsert <CR>"),
      dashboard.button("d", "   Dotfiles", ":silent SessionRestore /home/mn/NixConfig<CR>"),
      dashboard.button("o", "󰠮   Obsidian", ":silent SessionRestore /home/mn/Documents/Marius' Remote Vault<CR>"),
      dashboard.button("q", "󰛉   Quit", ":qa<CR>"),
    }

    alpha.setup(dashboard.config)
  end
};
