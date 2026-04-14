-- Show git hunks in sign-column and navigate betwenn them
return {
  "lewis6991/gitsigns.nvim",
  opts = {
    sign_priority = 100,
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns

      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation
      map("n", "<leader>gn", function()
        if vim.wo.diff then
          return "]h"
        end
        vim.schedule(function()
          gs.next_hunk()
        end)
        return "<Ignore>"
      end, { expr = true, desc = "Next Hunk" })

      map("n", "<leader>gp", function()
        if vim.wo.diff then
          return "[h"
        end
        vim.schedule(function()
          gs.prev_hunk()
        end)
        return "<Ignore>"
      end, { expr = true, desc = "Previous Hunk" })

      map("n", "<leader>gb", gs.toggle_current_line_blame, { desc = "Toggle Blame" })
      map("n", "<leader>gB", function()
        gs.blame_line({ full = true })
      end, { desc = "Blame Line" })
      map("n", "<leader>gd", gs.diffthis, { desc = "Diff This" })
      map("n", "<leader>gD", function()
        gs.diffthis("~")
      end, { desc = "Diff This ~" })
      map("n", "<leader>gt", gs.toggle_deleted, { desc = "Toggle Deleted" })
    end,
  }
}
