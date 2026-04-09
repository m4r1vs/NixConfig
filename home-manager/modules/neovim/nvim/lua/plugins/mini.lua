-- Collection of small useful enhancements
return {
  {
    -- Enable aliases for common surrounding chars (for example c-i-q to change inside any quotes)
    "echasnovski/mini.ai",
    version = false,
    opts = {
      mappings = {
        around_next = 'al',
        inside_next = 'il',
      }
    }
  },
  {
    -- Highlight the word under the cursor in the entire buffer
    "echasnovski/mini.cursorword",
    version = false,
    opts = {}
  },
  {
    -- Better diff view
    "echasnovski/mini.diff",
    version = false,
    opts = {
      view = {
        signs = { add = "", change = "", delete = "" },
        priority = 0,
      },
    }
  },
}
