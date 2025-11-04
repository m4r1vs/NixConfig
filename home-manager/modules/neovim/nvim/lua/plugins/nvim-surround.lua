-- Quickly surround text with characters
return {
  "kylechui/nvim-surround",
  event = "VeryLazy",
  opts = {
    keymaps = {
      insert = "<C-g>e",
      insert_line = "<C-g>E",
      normal = "ye",
      normal_cur = "yee",
      normal_line = "yE",
      normal_cur_line = "yEE",
      visual = "e",
      visual_line = "gE",
      delete = "de",
      change = "ce",
      change_line = "cE",
    },
  }
}
