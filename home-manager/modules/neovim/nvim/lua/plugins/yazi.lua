-- Use yazi as netrw replacement
return {
  "mikavilpas/yazi.nvim",
  keys = {
    {
      "<leader>ee",
      "<cmd>Yazi<cr>",
      desc = "Open at current file",
      mode = { "n" }
    },
    {
      "<leader>er",
      "<cmd>Yazi cwd<cr>",
      desc = "Open at project root",
      mode = { "n" }
    },
    {
      "<leader>ec",
      "<cmd>Yazi toggle<cr>",
      desc = "Resume last session",
      mode = { "n" }
    },
  },
  opts = {
    open_for_directories = true,
    floating_window_scaling_factor = 1,
    yazi_floating_window_border = "none",
    open_multiple_tabs = true,
    keymaps = {
      show_help = "<f1>",
      open_file_in_vertical_split = "<c-v>",
      open_file_in_horizontal_split = "<c-x>",
      open_file_in_tab = "<c-t>",
      grep_in_directory = "<c-s>",
      replace_in_directory = "<c-g>",
      cycle_open_buffers = "<tab>",
      copy_relative_path_to_selected_files = "<c-y>",
    },
  },
}
