-- Collection of small useful enhancements
return {
  { "echasnovski/mini.ai",         version = false, opts = {} },
  { "echasnovski/mini.cursorword", version = false, opts = {} },
  {
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
