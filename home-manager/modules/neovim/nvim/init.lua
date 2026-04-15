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

-- Set default colorscheme
vim.cmd("colorscheme cyberdream")

-- Set common options
vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 2
vim.opt.clipboard = "unnamedplus" -- use system clipboard
vim.opt.showtabline = 2
vim.opt.cursorline = true
vim.opt.swapfile = false -- do not create swapfile for unsaved files
vim.opt.smarttab = true
vim.opt.wrap = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir" -- persistent undo history
vim.opt.undofile = true
vim.opt.showmode = false
vim.opt.scrolloff = 12
vim.opt.sidescrolloff = 8
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.conceallevel = 1
vim.opt.pumheight = 12
vim.opt.hidden = true
vim.opt.hlsearch = true
vim.opt.inccommand = "split" -- live preview of substitutions
vim.wo.signcolumn = "yes:1"
vim.opt.linebreak = true

-- Folds (use za to toggle the fold, zR to unfold all and zM to fold all)
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true
vim.opt.fillchars:append({ fold = " " })
_G.custom_fold_text = function()
  local start_line = vim.fn.getline(vim.v.foldstart)
  local end_line = vim.fn.trim(vim.fn.getline(vim.v.foldend))
  local line_count = vim.v.foldend - vim.v.foldstart + 1
  return start_line .. "      [" .. line_count .. " lines]      " .. end_line
end
vim.opt.foldtext = "v:lua.custom_fold_text()"

-- Change settings if we're in the Browser
if vim.g.started_by_firenvim == true then
  vim.opt.showtabline = 0
  vim.opt.laststatus = 0
  vim.opt.cmdheight = 0
  vim.opt.wrap = true
  vim.cmd("set guifont=JetBrainsMono\\ Nerd\\ Font\\ Mono:h16")

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

-- use <leader>x to toggle the quickfix window
vim.keymap.set("n", "<leader>x", function()
  local qf_exists = false
  for _, win in pairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      qf_exists = true
    end
  end
  if qf_exists then
    vim.cmd("cclose")
  else
    vim.cmd("copen")
  end
end, { desc = "Toggle Quickfix" })

-- Treat .svx files as markdown
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.svx",
  command = "set filetype=markdown",
})

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

-- Move selected lines up and down in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { noremap = true, silent = true, desc = "Move lines down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { noremap = true, silent = true, desc = "Move lines up" })

-- Toggle booleans under cursor
vim.keymap.set("n", "<leader>rb", function()
  local word = vim.fn.expand("<cword>")
  local toggles = {
    ["true"] = "false",
    ["false"] = "true",
    ["True"] = "False",
    ["False"] = "True",
    ["TRUE"] = "FALSE",
    ["FALSE"] = "TRUE",
    ["on"] = "off",
    ["off"] = "on",
    ["On"] = "Off",
    ["Off"] = "On",
    ["ON"] = "OFF",
    ["OFF"] = "ON",
    ["yes"] = "no",
    ["no"] = "yes",
    ["Yes"] = "No",
    ["No"] = "Yes",
    ["YES"] = "NO",
    ["NO"] = "YES",
    ["0"] = "1",
    ["1"] = "0",
  }

  local new_word = toggles[word]
  if new_word then
    vim.cmd("normal! \"_ciw" .. new_word)
  end
end, { noremap = true, silent = true, desc = "Toggle Boolean" })

-- Remap > and < in visual mode to keep the selection
vim.api.nvim_set_keymap("v", ">", ">gv", { noremap = true, silent = true, desc = "Indent" })
vim.api.nvim_set_keymap("v", "<", "<gv", { noremap = true, silent = true, desc = "Outdent" })

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
vim.keymap.set("n", "<C-T>", ":tabnew<CR>:Telescope find_files<CR>", { desc = "New Tab + Telescope" })

-- Use <leader>r" to change ' to "
vim.keymap.set("v", "<leader>r\"", ":s/'/\"/g<CR>", { desc = "Change ' to \"" })
vim.keymap.set("n", "<leader>r\"", ":%s/'/\"/g<CR>", { desc = "Change ' to \"" })

-- Use <leader>rs to sort the current selection (visual) or inside brackets (normal)
vim.keymap.set("v", "<leader>rs", ":sort<CR>", { desc = "Sort Selection" })
vim.keymap.set("n", "<leader>rs", function()
  local function sort_in_pair(open, close)
    local start_pos = vim.fn.searchpairpos(open, "", close, "bnW")
    local end_pos = vim.fn.searchpairpos(open, "", close, "nW")
    if start_pos[1] > 0 and end_pos[1] > 0 and start_pos[1] < end_pos[1] then
      vim.cmd(string.format("%d,%dsort", start_pos[1] + 1, end_pos[1] - 1))
      return true
    end
    return false
  end

  if not sort_in_pair("\\[", "\\]") then
    if not sort_in_pair("{", "}") then
      -- Fallback: Sort block between empty lines (or start/end of file)
      local start_line = vim.fn.search("^\\s*$", "bnW")
      start_line = start_line == 0 and 1 or start_line + 1

      local end_line = vim.fn.search("^\\s*$", "nW")
      end_line = end_line == 0 and vim.fn.line("$") or end_line - 1

      if start_line <= end_line then
        vim.cmd(string.format("%d,%dsort", start_line, end_line))
      end
    end
  end
end, { noremap = true, silent = true, desc = "Sort in Brackets" })

-- Use <leader>ro to convert the current selection to an ordered list
vim.keymap.set("v", "<leader>ro", ":!nl -w 1 -s '. '<CR>", { desc = "Ordered List" })

-- Use <leader>rq to surround the current selection with triple backticks
vim.keymap.set("v", "<leader>rq", function()
  local old_reg = vim.fn.getreg('"')
  local old_regtype = vim.fn.getregtype('"')
  vim.cmd('normal! y')
  local text = vim.fn.getreg('"')
  local wrapped = "```\n" .. text .. "```"
  vim.fn.setreg('"', wrapped)
  vim.cmd('normal! gv""p')
  vim.fn.setreg('"', old_reg, old_regtype)
end, { desc = "Make Codeblock" })

-- Use <leader>uw to toggle word wrap
vim.keymap.set("n", "<leader>uw", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle Word Wrap" })

-- Use <leader>ur to restart neovim
vim.keymap.set("n", "<leader>ur", ":restart<CR>", { desc = "Restart NeoVim" })

-- Use <leader>un to toggle line numbers
vim.keymap.set("n", "<leader>un", function()
  if vim.wo.number and not vim.wo.relativenumber then
    vim.wo.number = false
  else
    vim.wo.number = true
    vim.wo.relativenumber = false
  end
end, { desc = "Toggle Line Numbers" })

-- Use <leader>uN to toggle relative line numbers
vim.keymap.set("n", "<leader>uN", function()
  if vim.wo.relativenumber then
    vim.wo.relativenumber = false
    vim.wo.number = false
  else
    vim.wo.relativenumber = true
    vim.wo.number = true
  end
end, { desc = "Toggle Relative Line Numbers" })

-- Toggle virtualedit (lets cursor move past end of line, great for visual block)
vim.keymap.set("n", "<leader>uv", function()
  if vim.o.virtualedit == "all" then
    vim.o.virtualedit = ""
  else
    vim.o.virtualedit = "all"
  end
end, { desc = "Toggle Virtual Edit" })

-- Update lazy.nvim plugins
vim.keymap.set("n", "<leader>uU", ":silent Lazy update<CR>", { desc = "Update Lazy Plugins" })

-- Toggle colorcolumn at 80 (highlights line length limit)
vim.keymap.set("n", "<leader>uc", function()
  if vim.wo.colorcolumn == "" then
    vim.wo.colorcolumn = "80"
  else
    vim.wo.colorcolumn = ""
  end
end, { desc = "Toggle Color Column" })

-- Toggle cursorcolumn (crosshair mode)
vim.keymap.set("n", "<leader>u+", function()
  vim.wo.cursorcolumn = not vim.wo.cursorcolumn
end, { desc = "Toggle Cursor Crosshair" })

-- Toggle conceal level (useful in markdown/JSON to see raw text)
vim.keymap.set("n", "<leader>uC", function()
  if vim.wo.conceallevel > 0 then
    vim.wo.conceallevel = 0
  else
    vim.wo.conceallevel = 2
  end
end, { desc = "Toggle Conceal" })

-- Toggle spell checking
vim.keymap.set("n", "<leader>us", function()
  vim.wo.spell = not vim.wo.spell
end, { desc = "Toggle Spell Check" })

-- Toggle scrolloff between 0 and 12 (controls how much context stays visible while scrolling)
vim.keymap.set("n", "<leader>uZ", function()
  if vim.o.scrolloff == 12 then
    vim.o.scrolloff = 0
  else
    vim.o.scrolloff = 12
  end
end, { desc = "Toggle Scrolloff" })

-- Toggle list mode (shows hidden chars: tabs, trailing spaces, etc.)
vim.keymap.set("n", "<leader>ul", function()
  vim.wo.list = not vim.wo.list
end, { desc = "Toggle List Mode (Show Hidden Chars)" })

-- Change cursor depending on mode
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"

-- save cursor position across sessions
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
    vim.hl.on_yank({ higroup = "YankHighlight", timeout = 100 })
  end,
})

-- Navigate quickly through Quickfix List
vim.keymap.set("n", "<F2>", vim.cmd.cprevious, { desc = "Previous Quickfix" })
vim.keymap.set("n", "<F3>", vim.cmd.cnext, { desc = "Next Quickfix" })

vim.keymap.set("n", "<F7>", vim.cmd.cprevious, { desc = "Previous Quickfix" })
vim.keymap.set("n", "<F9>", vim.cmd.cnext, { desc = "Next Quickfix" })

-- Resize splits with Ctrl+Alt+h/j/k/l
vim.keymap.set("n", "<C-M-h>", ":vertical resize -2<CR>", { noremap = true, silent = true, desc = "Resize split left" })
vim.keymap.set("n", "<C-M-l>", ":vertical resize +2<CR>", { noremap = true, silent = true, desc = "Resize split right" })
vim.keymap.set("n", "<C-M-k>", ":resize -2<CR>", { noremap = true, silent = true, desc = "Resize split up" })
vim.keymap.set("n", "<C-M-j>", ":resize +2<CR>", { noremap = true, silent = true, desc = "Resize split down" })

-- Close window with leader+q
vim.keymap.set("n", "<leader>q", "<C-w>q", { noremap = true, silent = true, desc = "Close Window/Split/Tab" })

-- Close all windows with leader+Q
vim.keymap.set("n", "<leader>Q", ":qa<CR>", { noremap = true, silent = true, desc = "Quit NeoVim" })

-- Close buffer with leader+c
vim.keymap.set("n", "<leader>c", ":bd<CR>", { noremap = true, silent = true, desc = "Close Buffer" })

-- Force close buffer with leader+C
vim.keymap.set("n", "<leader>C", ":bd!<CR>", { noremap = true, silent = true, desc = "Force Close Buffer" })

-- Save file with leader+ww
vim.keymap.set("n", "<leader>ww", ":w<CR>", { noremap = true, silent = true, desc = "Save File" })

-- Force save file with leader+wf
vim.keymap.set("n", "<leader>wf", ":w!<CR>", { noremap = true, silent = true, desc = "Force Save File" })

-- Save file without formatting with leader+wu
vim.keymap.set("n", "<leader>wu", ":noa w<CR>",
  { noremap = true, silent = true, desc = "Save File Without Formatting" })

-- Save file and quit with leader+wq
vim.keymap.set("n", "<leader>wq", ":wq<CR>", { noremap = true, silent = true, desc = "Save and Quit" })

-- Discard changes with leader+we
vim.keymap.set("n", "<leader>we", ":e!<CR>", { noremap = true, silent = true, desc = "Discard Changes" })

-- Never yank text that is pasted over
vim.keymap.set("x", "p", "P", { noremap = true, silent = true })

-- Use leader+p/P to always paste into a new line below/above current one
vim.keymap.set("n", "<Leader>p", "o<Esc>p", { noremap = true, silent = true, desc = "Paste Below" })
vim.keymap.set("n", "<Leader>P", "O<Esc>p", { noremap = true, silent = true, desc = "Paste Above" })

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
vim.keymap.set("n", "<leader>rw", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace word" })
vim.keymap.set("n", "<leader>rW", [[:%s/\<<C-r><C-a>\>/<C-r><C-a>/gI<Left><Left><Left>]], { desc = "Replace WORD" })

-- Use escape to remove highlights
vim.keymap.set("n", "<Esc>", [[<Esc><Cmd>nohlsearch<CR>]], { noremap = true, silent = true, desc = "Clear Highlight" })
