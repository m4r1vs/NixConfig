-- Disable netrw, use yazi instead
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Init LazyVim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
vim.g.mapleader = " "
vim.opt.termguicolors = true
vim.opt.guicursor = ""

require("lazy").setup("plugins", {
  rocks = { enabled = false },
})

vim.cmd("colorscheme cyberdream")

-- Set common options
vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 2
vim.opt.clipboard = "unnamedplus"
vim.opt.showtabline = 2
vim.opt.cursorline = true
vim.opt.swapfile = false
vim.opt.smarttab = true
vim.opt.wrap = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
vim.opt.showmode = false
vim.opt.scrolloff = 12
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.conceallevel = 1
vim.opt.pumheight = 12
vim.opt.hidden = true
vim.wo.signcolumn = "yes:1"
vim.o.termguicolors = true
vim.opt.linebreak = true

-- Change settings if we're in the Browser
if vim.g.started_by_firenvim == true then
  vim.opt.showtabline = 0
  vim.opt.laststatus = 0
  vim.opt.cmdheight = 0
  vim.opt.wrap = true
  vim.cmd("set guifont=JetBrainsMono\\ Nerd\\ Font\\ Mono:h10")

  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = "github.com_*.txt",
    command = "set filetype=markdown"
  })

  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = "*jira*.txt",
    command = "set filetype=markdown"
  })

  vim.g.firenvim_config = {
    localSettings = {
      [".*"] = {
        takeover = "never"
      }
    },
    globalSettings = {
      takeover = "never",
      ignoreKeys = {
        all = { "wC-1w", "<C-2>", "<C-3>", "<C-4>", "<C-5>", "<C-6>", "<C-7>", "<C-8>", "<C-9>", "<C-0>" },
        normal = { "<Tab>", "<S-Tab>", "<C-l>" }
      }
    }
  }
end

-- Configure Markdown text wrapping
vim.api.nvim_create_augroup('markdown_settings', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = 'markdown_settings',
  pattern = 'markdown',
  callback = function()
    vim.bo.textwidth = 170
    vim.wo.wrap = true
  end
})
vim.api.nvim_create_autocmd('BufWinEnter', {
  group = 'markdown_settings',
  pattern = '*',
  callback = function(args)
    if vim.bo[args.buf].filetype == 'markdown' then
      vim.o.wrap = true
    end
  end
})

-- Remap > and < in visual mode to keep the selection
vim.api.nvim_set_keymap("v", ">", ">gv", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<", "<gv", { noremap = true, silent = true })

-- Map j/k to gj/gk for wrapped line navigation
vim.keymap.set("n", "j", "gj", { noremap = true, silent = true })
vim.keymap.set("n", "k", "gk", { noremap = true, silent = true })

-- Add border to diagnostics (borders for other stuff in lspconfig.lua)
vim.diagnostic.config {
  virtual_text = true,
  source = true,
  float = {
    border = "rounded",
    focusable = true,
    source = true,
  },
}

-- Create new tab with CTRL-T and open telescope picker
vim.keymap.set("n", "<C-T>", ":tabnew<CR>:Telescope find_files<CR>")

-- Use <leader>" to change current selection ' to "
vim.keymap.set("v", "<leader>\"", ":s/'/\"/g<CR>")

-- Use <leader>rs to sort the current selection
vim.keymap.set("v", "<leader>rs", ":!sort<CR>")

-- Change cursor depending on mode
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"

-- save cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local row, col = unpack(vim.api.nvim_buf_get_mark(0, "\""))
    if row > 0 and row <= vim.api.nvim_buf_line_count(0) then
      vim.api.nvim_win_set_cursor(0, { row, col })
    end
  end,
})

-- Use pagedown for Going forward in history.
-- Map <C-i> to Pagedown in TerminalEmulator (fix for <C-i> == <Tab> ASCII escape)
-- See https://github.com/tmux/tmux/issues/2705
vim.api.nvim_set_keymap("n", "<PageDown>", "<C-i>", { noremap = true, silent = true })

-- use (shift-)tab to navigate tabs
vim.keymap.set("n", "<Tab>", "gt", { noremap = true, silent = true })
vim.keymap.set("n", "<S-Tab>", "gT", { noremap = true, silent = true })

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "YankHighlight", timeout = 100 })
  end,
})

-- Navigate quickly through Quickfix List
vim.keymap.set("n", "<F2>", vim.cmd.cprevious)
vim.keymap.set("n", "<F3>", vim.cmd.cnext)

vim.keymap.set("n", "<F7>", vim.cmd.cprevious)
vim.keymap.set("n", "<F9>", vim.cmd.cnext)

-- Resize splits with Ctrl+Alt+h/j/k/l
vim.keymap.set("n", "<C-M-h>", ":vertical resize -2<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-M-l>", ":vertical resize +2<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-M-k>", ":resize -2<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-M-j>", ":resize +2<CR>", { noremap = true, silent = true })

-- Close window with leader+q
vim.keymap.set("n", "<leader>q", "<C-w>q", { noremap = true, silent = true })

-- Close all windows with leader+Q
vim.keymap.set("n", "<leader>Q", ":qa<CR>", { noremap = true, silent = true })

-- Close buffer with leader+c
vim.keymap.set("n", "<leader>c", ":bd<CR>", { noremap = true, silent = true })

-- Force close buffer with leader+C
vim.keymap.set("n", "<leader>C", ":bd!<CR>", { noremap = true, silent = true })

-- Never yank text that is pasted over
vim.keymap.set("x", "p", "P", { noremap = true, silent = true })

-- Use leader+p/P to always paste into a new line below/above current one
vim.keymap.set("n", "<Leader>p", "o<Esc>p", { noremap = true, silent = true })
vim.keymap.set("n", "<Leader>P", "O<Esc>p", { noremap = true, silent = true })

-- Do not show diagnostics icons next to line numbers
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.HINT] = "",
    },
    numhl = {
      [vim.diagnostic.severity.ERROR] = "ErrorMsg",
    },
  },
})

-- Use leader+w/W to replace all occurances of the current word/WORD in the file
vim.keymap.set("n", "<leader>w", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>W", [[:%s/\<<C-r><C-a>\>/<C-r><C-a>/gI<Left><Left><Left>]])

-- Use escape to remove highlights
vim.keymap.set("n", "<Esc>", [[<Esc><Cmd>nohlsearch<CR>]], { noremap = true, silent = true })
