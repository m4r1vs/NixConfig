-- Automatically set the CWD to the git-root
return {
  "notjedi/nvim-rooter.lua",
  config = function()
    require("nvim-rooter").setup()
  end
}
